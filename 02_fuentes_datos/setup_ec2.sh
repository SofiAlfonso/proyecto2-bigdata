#!/bin/bash
# User data de la EC2 "fuente-archivos" (puntos 2 y 3). AWS lo ejecuta como root, solo en el primer arranque.
# Instala el cliente MariaDB y cron (Amazon Linux 2023 no trae cron) y deja en
# /home/ec2-user/datos los scripts del repo que se ejecutan en la EC2.
set -euo pipefail

REPO=https://raw.githubusercontent.com/SofiAlfonso/proyecto2-bigdata/main
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
chmod +x "$DIR"/*.sh
chown -R ec2-user:ec2-user "$DIR"
