#!/bin/bash
# Ejecuta un archivo .hql como paso (step) en el cluster EMR_CLUSTER_ID de .env e imprime su salida.
# El paso corre "hive -f" en el maestro y sube su salida a s3://<bucket>/emr-salidas/, asi que no
# hace falta SSH ni activar los registros de EMR en S3 (que tardan ~5 min en aparecer).
# Sirve para el punto 5 y para las consultas Hive del punto 6.
# Donde: terminal del Learner Lab (o CloudShell), despues de crear_emr.sh.
# Uso:   bash 05_catalogacion/ejecutar_hive.sh <archivo.hql>
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"
: "${EMR_CLUSTER_ID:?Falta EMR_CLUSTER_ID en .env (lo llena crear_emr.sh)}"
HQL="${1:?Uso: ejecutar_hive.sh <archivo.hql>}"
ARCHIVO=$(basename "$HQL")
NOMBRE="${ARCHIVO%.*}"
SCRIPT_S3="s3://$BUCKET_NAME/scripts/$ARCHIVO"
SALIDA_S3="s3://$BUCKET_NAME/emr-salidas/$NOMBRE"

aws s3 cp "$HQL" "$SCRIPT_S3" --only-show-errors

# Lo que corre en el maestro: baja el .hql, ejecuta Hive y sube resultado (.out) y mensajes (.err)
CMD="aws s3 cp $SCRIPT_S3 /tmp/$ARCHIVO --only-show-errors \
&& hive -f /tmp/$ARCHIVO > /tmp/$NOMBRE.out 2> /tmp/$NOMBRE.err; RC=\$?; \
aws s3 cp /tmp/$NOMBRE.out $SALIDA_S3.out --only-show-errors; \
aws s3 cp /tmp/$NOMBRE.err $SALIDA_S3.err --only-show-errors; exit \$RC"
PASO=$(python3 -c 'import json, sys; print(json.dumps([{"Type": "CUSTOM_JAR", "Name": sys.argv[1],
  "ActionOnFailure": "CONTINUE", "Jar": "command-runner.jar", "Args": ["bash", "-c", sys.argv[2]]}]))' \
  "hive $NOMBRE" "$CMD")

STEP_ID=$(aws emr add-steps --cluster-id "$EMR_CLUSTER_ID" --steps "$PASO" \
  --query 'StepIds[0]' --output text)
echo "Paso $STEP_ID en ejecucion..."

if ! aws emr wait step-complete --cluster-id "$EMR_CLUSTER_ID" --step-id "$STEP_ID"; then
  echo "El paso fallo. Mensajes de Hive:"
  aws s3 cp "$SALIDA_S3.err" - 2>/dev/null | tail -n 30
  exit 1
fi
aws s3 cp "$SALIDA_S3.out" -
