#!/bin/bash
# Ejecuta un archivo .hql como paso (step) de Hive en el cluster EMR_CLUSTER_ID de .env e imprime su salida.
# Evita entrar por SSH al nodo maestro. Sirve para el punto 5 y para las consultas Hive del punto 6.
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
DESTINO="s3://$BUCKET_NAME/scripts/$(basename "$HQL")"

aws s3 cp "$HQL" "$DESTINO" --only-show-errors
STEP_ID=$(aws emr add-steps --cluster-id "$EMR_CLUSTER_ID" \
  --steps "Type=HIVE,Name=$(basename "$HQL"),ActionOnFailure=CONTINUE,Args=[-f,$DESTINO]" \
  --query 'StepIds[0]' --output text)
echo "Paso $STEP_ID en ejecucion..."

LOGS="s3://$BUCKET_NAME/logs/emr/$EMR_CLUSTER_ID/steps/$STEP_ID"
if ! aws emr wait step-complete --cluster-id "$EMR_CLUSTER_ID" --step-id "$STEP_ID"; then
  echo "El paso fallo. Error en $LOGS/stderr.gz (aparece en S3 a los ~5 min)."
  exit 1
fi

# EMR copia los logs del paso a S3 cada ~5 min; se reintenta hasta que aparezca la salida
for _ in $(seq 1 20); do
  if aws s3 cp "$LOGS/stdout.gz" - 2>/dev/null | gunzip 2>/dev/null; then exit 0; fi
  sleep 30
done
echo "La salida aun no esta en $LOGS/stdout.gz; verla luego en la consola de EMR (Steps > View logs)."
