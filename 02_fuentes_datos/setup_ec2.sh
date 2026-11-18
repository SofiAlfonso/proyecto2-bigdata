#!/bin/bash
# User data de la EC2 "fuente-archivos" (puntos 2 y 3). AWS lo ejecuta como root, solo en el primer arranque.
# infra/02_ec2.sh le antepone REPO_GITHUB, RAMA y BUCKET_NAME tomados de .env.
# (Si se pega a mano en la consola de EC2, agregar esas 3 lineas despues de la primera.)
# Instala el cliente MariaDB y cron (Amazon Linux 2023 no trae cron), deja en
# /home/ec2-user/datos los scripts del repo y un .env con el bucket para ingesta.sh.
set -euo pipefail
: "${REPO_GITHUB:?}" "${RAMA:?}" "${BUCKET_NAME:?}"

REPO="https://raw.githubusercontent.com/$REPO_GITHUB/$RAMA"
DIR=/home/ec2-user/datos

dnf install -y mariadb105 cronie
systemctl enable --now crond

mkdir -p "$DIR"
for f in 02_fuentes_datos/descargar_temperatura.sh \
         02_fuentes_datos/descargar_catalogo.sh \
         02_fuentes_datos/cargar_catalogo.sql \
         02_fuentes_datos/my.cnf.ejemplo \
         03_ingesta_datalake/ingesta.sh \
         03_ingesta_datalake/programar_ingesta.sh; do
  curl -fsSL -o "$DIR/$(basename "$f")" "$REPO/$f"
done
echo "BUCKET_NAME=$BUCKET_NAME" > "$DIR/.env"
chmod +x "$DIR"/*.sh
chown -R ec2-user:ec2-user "$DIR"
