#!/bin/bash
# Punto 4: sube raw_to_trusted.py, crea el job de Glue "raw_to_trusted" y lo ejecuta hasta que termine.
# Donde: terminal del Learner Lab (o CloudShell), desde la raiz del repo, con raw/ ya poblado.
# Uso:   bash 04_preparacion_glue_spark/crear_job_glue.sh <nombre-del-bucket>
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
BUCKET_NAME="${1:?Uso: crear_job_glue.sh <nombre-del-bucket>}"
cd "$(dirname "$0")"

# El script trae fijo el bucket original; se sube una copia con el bucket de este despliegue
sed "s#^BUCKET = .*#BUCKET = \"s3://$BUCKET_NAME\"#" raw_to_trusted.py > /tmp/raw_to_trusted.py
aws s3 cp /tmp/raw_to_trusted.py "s3://$BUCKET_NAME/scripts/raw_to_trusted.py" --only-show-errors

# Igual que la evidencia: workers G.1X, 2 DPU. LabRole es el unico rol que permite el Learner Lab.
if ! aws glue get-job --job-name raw_to_trusted >/dev/null 2>&1; then
  aws glue create-job --name raw_to_trusted --role LabRole \
    --command "Name=glueetl,ScriptLocation=s3://$BUCKET_NAME/scripts/raw_to_trusted.py,PythonVersion=3" \
    --glue-version 5.0 --worker-type G.1X --number-of-workers 2 \
    --query Name --output text
fi

RUN_ID=$(aws glue start-job-run --job-name raw_to_trusted --query JobRunId --output text)
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
