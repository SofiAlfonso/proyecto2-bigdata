#!/bin/bash
# Punto 4: sube raw_to_trusted.py, crea el job de Glue "raw_to_trusted" y lo ejecuta hasta que termine.
# El bucket (BUCKET_NAME de .env) se le pasa al job como argumento --BUCKET_NAME.
# Donde: terminal del Learner Lab (o CloudShell), con raw/ ya poblado.
# Uso:   bash 04_preparacion_glue_spark/crear_job_glue.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"
ARGS="{\"--BUCKET_NAME\":\"$BUCKET_NAME\"}"

aws s3 cp "$RAIZ/04_preparacion_glue_spark/raw_to_trusted.py" \
  "s3://$BUCKET_NAME/scripts/raw_to_trusted.py" --only-show-errors

# Igual que la evidencia: workers G.1X, 2 DPU. LabRole es el unico rol que permite el Learner Lab.
if ! aws glue get-job --job-name raw_to_trusted >/dev/null 2>&1; then
  aws glue create-job --name raw_to_trusted --role LabRole \
    --command "Name=glueetl,ScriptLocation=s3://$BUCKET_NAME/scripts/raw_to_trusted.py,PythonVersion=3" \
    --default-arguments "$ARGS" \
    --glue-version 5.0 --worker-type G.1X --number-of-workers 2 \
    --query Name --output text
fi

RUN_ID=$(aws glue start-job-run --job-name raw_to_trusted --arguments "$ARGS" \
  --query JobRunId --output text)
echo "Corrida $RUN_ID"
while true; do
  ESTADO=$(aws glue get-job-run --job-name raw_to_trusted --run-id "$RUN_ID" \
    --query JobRun.JobRunState --output text)
  echo "$(date +%T) $ESTADO"
  case "$ESTADO" in
    SUCCEEDED) break ;;
    FAILED|ERROR|TIMEOUT|STOPPED) echo "Ver el error en CloudWatch: /aws-glue/jobs/error"; exit 1 ;;
  esac
  sleep 30
done
aws s3 ls "s3://$BUCKET_NAME/trusted/" --recursive --human-readable
