#!/bin/bash
# Ingesta automatica hacia el data lake (S3, zona raw).
# Se ejecuta en la EC2. Las credenciales de RDS estan en ~/.my.cnf (no en este archivo).
set -e

DIR="$HOME/datos"
# El bucket cambia segun quien despliega: se lee de ~/datos/.env, que crea setup_ec2.sh.
# shellcheck source=/dev/null
source "$DIR/.env"
BUCKET="s3://${BUCKET_NAME:?Falta BUCKET_NAME en ~/datos/.env}/raw"
TS=$(date +%Y%m%d_%H%M%S)
log() { echo "$(date '+%F %T') $1"; }

log "Inicio de ingesta"

# 1) ARCHIVOS: CSV historico de temperatura que vive en la EC2.
#    sync solo sube lo que no esta ya en S3 (evita resubir 251 MB cada vez).
aws s3 sync "$DIR" "$BUCKET/temperatura_historica/" \
  --exclude "*" --include "temperatura_*.csv" --only-show-errors
log "Historico OK"

# 2) BASE DE DATOS: tabla estaciones de RDS MariaDB, exportada como TSV (separado por tabs).
mysql --ssl -B -e "SELECT * FROM ideam.estaciones" > "$DIR/catalogo_estaciones.tsv"
aws s3 cp "$DIR/catalogo_estaciones.tsv" \
  "$BUCKET/catalogo_estaciones/catalogo_estaciones.tsv" --only-show-errors
log "RDS OK"

# 3) URL: datos recientes de la API de datos.gov.co. Cada corrida deja un archivo nuevo.
curl -s -g --max-time 120 -G "https://www.datos.gov.co/resource/57sv-p2fu.csv" \
  --data-urlencode "\$limit=200000" -o "$DIR/estaciones_recientes_$TS.csv"
aws s3 cp "$DIR/estaciones_recientes_$TS.csv" \
  "$BUCKET/estaciones_recientes/estaciones_recientes_$TS.csv" --only-show-errors
rm -f "$DIR/estaciones_recientes_$TS.csv"
log "URL OK"

log "Fin de ingesta"
