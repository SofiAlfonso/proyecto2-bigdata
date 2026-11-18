#!/bin/bash
# Puntos 6 y 7: ejecuta un archivo en el cluster EMR_CLUSTER_ID de .env con el motor indicado
# e imprime su salida. Igual que ejecutar_hive.sh: el paso sube su salida a s3://<bucket>/emr-salidas/.
#   hive      -> hive -f        (base ideam_trusted, con encabezados y la consulta antes de cada resultado)
#   spark-sql -> spark-sql -f   (igual que hive, pero con el motor de Spark)
#   pyspark   -> spark-submit   (script de Python del punto 7)
# Donde: terminal del Learner Lab (o CloudShell), con el cluster en estado WAITING.
# Uso:   bash 06_consultas_sql/ejecutar_emr.sh hive      06_consultas_sql/consultas.sql
#        bash 06_consultas_sql/ejecutar_emr.sh spark-sql 06_consultas_sql/consultas.sql
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"
: "${EMR_CLUSTER_ID:?Falta EMR_CLUSTER_ID en .env (lo llena crear_emr.sh)}"
USO="Uso: ejecutar_emr.sh <hive|spark-sql|pyspark> <archivo>"
MOTOR="${1:?$USO}"
ORIGEN="${2:?$USO}"
ARCHIVO=$(basename "$ORIGEN")
NOMBRE="${MOTOR}_${ARCHIVO%.*}"
SCRIPT_S3="s3://$BUCKET_NAME/scripts/$ARCHIVO"
SALIDA_S3="s3://$BUCKET_NAME/emr-salidas/$NOMBRE"

# Las consultas no traen el nombre de la base (FROM temperatura): se fija con --database
OPCIONES_SQL="--database ideam_trusted --hiveconf hive.cli.print.header=true -v -f /tmp/$ARCHIVO"
case "$MOTOR" in
  hive)      EJECUTAR="hive $OPCIONES_SQL" ;;
  spark-sql) EJECUTAR="spark-sql $OPCIONES_SQL" ;;
  pyspark)   EJECUTAR="spark-submit /tmp/$ARCHIVO" ;;
  *) echo "$USO"; exit 1 ;;
esac

aws s3 cp "$ORIGEN" "$SCRIPT_S3" --only-show-errors

# Lo que corre en el maestro: baja el archivo, lo ejecuta y sube resultado (.out) y mensajes (.err)
CMD="aws s3 cp $SCRIPT_S3 /tmp/$ARCHIVO --only-show-errors \
&& $EJECUTAR > /tmp/$NOMBRE.out 2> /tmp/$NOMBRE.err; RC=\$?; \
aws s3 cp /tmp/$NOMBRE.out $SALIDA_S3.out --only-show-errors; \
aws s3 cp /tmp/$NOMBRE.err $SALIDA_S3.err --only-show-errors; exit \$RC"
PASO=$(python3 -c 'import json, sys; print(json.dumps([{"Type": "CUSTOM_JAR", "Name": sys.argv[1],
  "ActionOnFailure": "CONTINUE", "Jar": "command-runner.jar", "Args": ["bash", "-c", sys.argv[2]]}]))' \
  "$NOMBRE" "$CMD")

STEP_ID=$(aws emr add-steps --cluster-id "$EMR_CLUSTER_ID" --steps "$PASO" \
  --query 'StepIds[0]' --output text)
echo "Paso $STEP_ID ($MOTOR) en ejecucion..."

if ! aws emr wait step-complete --cluster-id "$EMR_CLUSTER_ID" --step-id "$STEP_ID"; then
  echo "El paso fallo. Ultimos mensajes:"
  aws s3 cp "$SALIDA_S3.err" - 2>/dev/null | tail -n 30
  exit 1
fi
aws s3 cp "$SALIDA_S3.out" -
echo "(salida guardada en $SALIDA_S3.out)"
