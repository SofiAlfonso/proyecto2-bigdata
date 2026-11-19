#!/bin/bash
# Punto 8, paso 4: abre el puerto 8501 de la EC2 "fuente-archivos" solo para tu IP e imprime la URL de la app.
# Tu IP: abrir https://checkip.amazonaws.com en el navegador del computador desde donde veras la app.
# Donde: terminal del Learner Lab (o CloudShell).
# Uso:   bash 08_visualizacion_api/abrir_puerto_streamlit.sh <tu-ip>
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
MI_IP="${1:?Uso: abrir_puerto_streamlit.sh <tu-ip>  (ver https://checkip.amazonaws.com)}"

SG=$(aws ec2 describe-security-groups --filters Name=group-name,Values=fuente-archivos-sg \
  --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 8501 \
  --cidr "$MI_IP/32" --query Return --output text \
  || echo "(la regla para $MI_IP ya existia)"

IP=$(aws ec2 describe-instances --filters Name=tag:Name,Values=fuente-archivos Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "App: http://$IP:8501"
