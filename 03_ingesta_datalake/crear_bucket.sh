#!/bin/bash
# Punto 3: crea el data lake, el bucket BUCKET_NAME de .env con las zonas raw, trusted y refined.
# Donde: terminal del Learner Lab (o CloudShell), con .env creado en la raiz del repo.
# Uso:   bash 03_ingesta_datalake/crear_bucket.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"

aws s3 mb "s3://$BUCKET_NAME"
for z in raw trusted refined; do
  aws s3api put-object --bucket "$BUCKET_NAME" --key "$z/" >/dev/null
done
aws s3 ls "s3://$BUCKET_NAME/"
