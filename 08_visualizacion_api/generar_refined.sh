#!/bin/bash
# Punto 8, paso 1: ejecuta en Athena cada consulta de 06_consultas_sql/consultas.sql y guarda su
# resultado en s3://<bucket>/refined/consultas/<id>.csv (q1, q2a, q2b, ..., q7).
# Esa zona refined es la que lee la API (Lambda + API Gateway).
# Donde: terminal del Learner Lab (o CloudShell), despues de crear_crawler.sh.
# Uso:   bash 08_visualizacion_api/generar_refined.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"
SALIDA="s3://$BUCKET_NAME/athena-resultados/"
DESTINO="s3://$BUCKET_NAME/refined/consultas"

# Separa consultas.sql en "id<TAB>consulta en una linea"; el id sale del comentario "-- Q1." de cada una
LISTA=$(mktemp)
python3 - "$RAIZ/06_consultas_sql/consultas.sql" > "$LISTA" <<'EOF'
import re, sys
for bloque in open(sys.argv[1], encoding="utf-8").read().split(";"):
    m = re.search(r"^--\s*(Q\w+)\.", bloque, re.M)
    sql = " ".join(l.strip() for l in bloque.splitlines() if l.strip() and not l.strip().startswith("--"))
    if m and sql:
        print(f"{m.group(1).lower()}\t{sql}")
EOF

while IFS=$'\t' read -r ID SQL; do
  QID=$(aws athena start-query-execution --work-group primary \
    --query-execution-context Database=ideam_trusted --query-string "$SQL" \
    --result-configuration "OutputLocation=$SALIDA" --query QueryExecutionId --output text)
  while true; do
    ESTADO=$(aws athena get-query-execution --query-execution-id "$QID" \
      --query QueryExecution.Status.State --output text)
    case "$ESTADO" in
      SUCCEEDED) break ;;
      FAILED|CANCELLED)
        echo "$ID fallo: $(aws athena get-query-execution --query-execution-id "$QID" \
          --query QueryExecution.Status.StateChangeReason --output text)"; exit 1 ;;
    esac
    sleep 2
  done
  # Athena deja el resultado en <SALIDA>/<id de ejecucion>.csv; se copia con un nombre fijo
  aws s3 cp "${SALIDA}${QID}.csv" "$DESTINO/$ID.csv" --only-show-errors
  echo "$ID -> refined/consultas/$ID.csv ($(($(aws s3 cp "$DESTINO/$ID.csv" - | wc -l) - 1)) filas)"
done < "$LISTA"
rm -f "$LISTA"
aws s3 ls "$DESTINO/"
