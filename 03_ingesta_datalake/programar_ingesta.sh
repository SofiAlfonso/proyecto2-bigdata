#!/bin/bash
# Punto 3: corre ingesta.sh una vez y la programa en cron cada 10 minutos (la misma linea de la evidencia).
# El bucket sale de ~/datos/.env, que crea setup_ec2.sh a partir del .env del repo.
# Donde: en la EC2, como ec2-user, cuando ya existen ~/.my.cnf y temperatura_abr_jun_2025.csv.
# Uso:   bash ~/datos/programar_ingesta.sh
set -euo pipefail
DIR=/home/ec2-user/datos
# shellcheck source=/dev/null
source "$DIR/.env"
echo "Bucket: ${BUCKET_NAME:?Falta BUCKET_NAME en $DIR/.env}"

# Corrida manual de prueba
"$DIR/ingesta.sh"

# Programacion: reemplaza la linea anterior de ingesta, si existe, en lugar de duplicarla
LINEA="*/10 * * * * $DIR/ingesta.sh >> $DIR/ingesta.log 2>&1"
{ crontab -l 2>/dev/null | grep -vF "$DIR/ingesta.sh" || true; echo "$LINEA"; } | crontab -
crontab -l
systemctl is-active crond
