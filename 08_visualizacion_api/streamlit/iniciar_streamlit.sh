#!/bin/bash
# Punto 8, paso 3: instala lo necesario y deja corriendo la app Streamlit en el puerto 8501.
# Donde: en la EC2 "fuente-archivos", como ec2-user, en la carpeta donde esta app.py.
# Uso:   bash iniciar_streamlit.sh <API_URL>     (la URL que imprimio crear_api.sh)
set -euo pipefail
API_URL="${1:?Uso: iniciar_streamlit.sh <API_URL>}"
cd "$(dirname "$0")"

# Python 3.11 (el Python por defecto de Amazon Linux 2023 es 3.9, viejo para Streamlit)
command -v python3.11 >/dev/null || sudo dnf install -y python3.11 python3.11-pip
python3.11 -m pip install --user --quiet streamlit pandas matplotlib requests

echo "API_URL=$API_URL" > .env

# Reinicia la app si ya estaba corriendo; nohup la mantiene viva al cerrar la sesion
pkill -f "streamlit run app.py" || true
nohup python3.11 -m streamlit run app.py --server.port 8501 --server.address 0.0.0.0 \
  --server.headless true > streamlit.log 2>&1 &
sleep 8
tail -n 5 streamlit.log

TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "App: http://$IP:8501   (requiere el puerto 8501 abierto: abrir_puerto_streamlit.sh)"
