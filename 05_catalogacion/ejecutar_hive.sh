#!/bin/bash
# Ejecuta un archivo .hql como paso (step) de Hive en el cluster EMR e imprime su salida.
# Evita entrar por SSH al nodo maestro. Sirve para el punto 5 y para las consultas Hive del punto 6.
# Donde: terminal del Learner Lab (o CloudShell), desde la raiz del repo.
# Uso:   bash 05_catalogacion/ejecutar_hive.sh <cluster-id> <nombre-del-bucket> <archivo.hql>
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
USO="Uso: ejecutar_hive.sh <cluster-id> <nombre-del-bucket> <archivo.hql>"
CLUSTER_ID="${1:?$USO}"
BUCKET_NAME="${2:?$USO}"
HQL="${3:?$USO}"
DESTINO="s3://$BUCKET_NAME/scripts/$(basename "$HQL")"

aws s3 cp "$HQL" "$DESTINO" --only-show-errors
STEP_ID=$(aws emr add-steps --cluster-id "$CLUSTER_ID" \
  --steps "Type=HIVE,Name=$(basename "$HQL"),ActionOnFailure=CONTINUE,Args=[-f,$DESTINO]" \
  --query 'StepIds[0]' --output text)
echo "Paso $STEP_ID en ejecucion..."

LOGS="s3://$BUCKET_NAME/logs/emr/$CLUSTER_ID/steps/$STEP_ID"
if ! aws emr wait step-complete --cluster-id "$CLUSTER_ID" --step-id "$STEP_ID"; then
  echo "El paso fallo. Error en $LOGS/stderr.gz (aparece en S3 a los ~5 min)."
  exit 1
fi

# EMR copia los logs del paso a S3 cada ~5 min; se reintenta hasta que aparezca la salida
for _ in $(seq 1 20); do
  if aws s3 cp "$LOGS/stdout.gz" - 2>/dev/null | gunzip 2>/dev/null; then exit 0; fi
  sleep 30
done
echo "La salida aun no esta en $LOGS/stdout.gz; verla luego en la consola de EMR (Steps > View logs)."
