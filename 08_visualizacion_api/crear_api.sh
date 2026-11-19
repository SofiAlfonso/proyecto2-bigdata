#!/bin/bash
# Punto 8, paso 2: crea (o actualiza) la Lambda "ideam-api" y la expone con un HTTP API de API Gateway.
# Guarda la URL publica en API_URL de .env y prueba las dos rutas.
# Donde: terminal del Learner Lab (o CloudShell), despues de generar_refined.sh.
# Uso:   bash 08_visualizacion_api/crear_api.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"
FUNCION=ideam-api
CUENTA=$(aws sts get-caller-identity --query Account --output text)
ROL="arn:aws:iam::$CUENTA:role/LabRole"     # el Learner Lab no permite crear roles

# Empaquetar el codigo (zip con Python, para no depender del comando zip)
ZIP="$(mktemp -d)/lambda.zip"
(cd "$RAIZ/08_visualizacion_api/lambda" && python3 -m zipfile -c "$ZIP" lambda_function.py)

if aws lambda get-function --function-name "$FUNCION" >/dev/null 2>&1; then
  aws lambda update-function-code --function-name "$FUNCION" --zip-file "fileb://$ZIP" \
    --query LastUpdateStatus --output text
  aws lambda wait function-updated-v2 --function-name "$FUNCION"
  aws lambda update-function-configuration --function-name "$FUNCION" \
    --environment "Variables={BUCKET_NAME=$BUCKET_NAME}" --query LastUpdateStatus --output text
  aws lambda wait function-updated-v2 --function-name "$FUNCION"
else
  aws lambda create-function --function-name "$FUNCION" --runtime python3.12 \
    --handler lambda_function.handler --role "$ROL" --zip-file "fileb://$ZIP" --timeout 10 \
    --environment "Variables={BUCKET_NAME=$BUCKET_NAME}" --query FunctionArn --output text
  aws lambda wait function-active-v2 --function-name "$FUNCION"
fi
LAMBDA_ARN=$(aws lambda get-function --function-name "$FUNCION" --query Configuration.FunctionArn --output text)

# HTTP API "rapido": una ruta por defecto que manda cualquier GET a la Lambda, con etapa que se despliega sola
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='$FUNCION'].ApiId | [0]" --output text)
if [ "$API_ID" = "None" ]; then
  API_ID=$(aws apigatewayv2 create-api --name "$FUNCION" --protocol-type HTTP --target "$LAMBDA_ARN" \
    --query ApiId --output text)
  # Permiso para que API Gateway invoque la Lambda
  aws lambda add-permission --function-name "$FUNCION" --statement-id apigateway-invoke \
    --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$AWS_REGION:$CUENTA:$API_ID/*" >/dev/null
fi
API_URL=$(aws apigatewayv2 get-api --api-id "$API_ID" --query ApiEndpoint --output text)

# Guardar la URL en .env (reemplaza el valor anterior)
if grep -q '^API_URL=' "$RAIZ/.env"; then
  sed -i "s#^API_URL=.*#API_URL=$API_URL#" "$RAIZ/.env"
else
  echo "API_URL=$API_URL" >> "$RAIZ/.env"
fi

echo "API: $API_URL (guardada en .env)"
echo "--- GET /consultas";    curl -s "$API_URL/consultas"; echo
echo "--- GET /consultas/q1"; curl -s "$API_URL/consultas/q1" | head -c 400; echo
