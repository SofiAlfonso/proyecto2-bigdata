#!/bin/bash
# Punto 5, Glue: crea la base "ideam_trusted" en el catalogo de Glue y el crawler "crawler_trusted",
# que registra una tabla por carpeta de trusted/. Luego lo ejecuta y lista las tablas.
# Donde: terminal del Learner Lab (o CloudShell), despues de crear_job_glue.sh.
# Uso:   bash 05_catalogacion/crear_crawler.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
T="s3://${BUCKET_NAME:?Falta BUCKET_NAME en .env}/trusted"

aws glue get-database --name ideam_trusted >/dev/null 2>&1 \
  || aws glue create-database --database-input Name=ideam_trusted

if ! aws glue get-crawler --name crawler_trusted >/dev/null 2>&1; then
  aws glue create-crawler --name crawler_trusted --role LabRole --database-name ideam_trusted \
    --targets "{\"S3Targets\":[{\"Path\":\"$T/catalogo_estaciones/\"},{\"Path\":\"$T/temperatura/\"},{\"Path\":\"$T/estaciones_recientes/\"}]}"
fi

aws glue start-crawler --name crawler_trusted
sleep 15
while [ "$(aws glue get-crawler --name crawler_trusted --query Crawler.State --output text)" != "READY" ]; do
  echo "$(date +%T) crawler en ejecucion..."
  sleep 20
done
echo "Ultima corrida: $(aws glue get-crawler --name crawler_trusted --query Crawler.LastCrawl.Status --output text)"
aws glue get-tables --database-name ideam_trusted \
  --query 'TableList[].[Name, StorageDescriptor.Location]' --output table
