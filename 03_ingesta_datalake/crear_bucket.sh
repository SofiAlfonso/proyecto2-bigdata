#!/bin/bash
# Punto 3: crea el data lake, un bucket S3 con las zonas raw, trusted y refined.
# Donde: terminal del Learner Lab (o CloudShell, o la EC2).
# Uso:   bash 03_ingesta_datalake/crear_bucket.sh <nombre-unico-del-bucket>
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
BUCKET_NAME="${1:?Uso: crear_bucket.sh <nombre-unico-del-bucket>}"

aws s3 mb "s3://$BUCKET_NAME"
for z in raw trusted refined; do
  aws s3api put-object --bucket "$BUCKET_NAME" --key "$z/" >/dev/null
done
aws s3 ls "s3://$BUCKET_NAME/"
