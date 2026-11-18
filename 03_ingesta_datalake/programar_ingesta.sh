#!/bin/bash
# Punto 3: apunta ingesta.sh al bucket de este despliegue, la corre una vez y la programa en cron
# cada 10 minutos (la misma linea de la evidencia).
# Donde: en la EC2, como ec2-user, cuando ya existen ~/.my.cnf y temperatura_abr_jun_2025.csv.
# Uso:   bash ~/datos/programar_ingesta.sh <nombre-del-bucket>
set -euo pipefail
BUCKET_NAME="${1:?Uso: programar_ingesta.sh <nombre-del-bucket>}"
DIR=/home/ec2-user/datos

# ingesta.sh trae fijo el bucket original; se cambia solo la copia de la EC2, no el repo
sed -i "s#s3://[^/\"]*/raw#s3://$BUCKET_NAME/raw#" "$DIR/ingesta.sh"
chmod +x "$DIR/ingesta.sh"
grep -n '^BUCKET=' "$DIR/ingesta.sh"

# Corrida manual de prueba
"$DIR/ingesta.sh"

# Programacion: reemplaza la linea anterior de ingesta, si existe, en lugar de duplicarla
LINEA="*/10 * * * * $DIR/ingesta.sh >> $DIR/ingesta.log 2>&1"
{ crontab -l 2>/dev/null | grep -vF "$DIR/ingesta.sh" || true; echo "$LINEA"; } | crontab -
crontab -l
systemctl is-active crond
