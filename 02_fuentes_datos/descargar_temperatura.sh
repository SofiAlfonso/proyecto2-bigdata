#!/bin/bash
# Descarga la temperatura del aire (IDEAM, datos.gov.co, dataset sbwg-7ju4)
# de abril a junio de 2025, un dia a la vez, y la une en un solo CSV.
BASE="https://www.datos.gov.co/resource/sbwg-7ju4.csv"
OUT="temperatura_abr_jun_2025.csv"

rm -f "$OUT"
d="2025-04-01"
while [ "$d" != "2025-07-01" ]; do
  next=$(date -d "$d + 1 day" +%F)
  curl -s -g --retry 3 --max-time 120 -G "$BASE" \
    --data-urlencode "\$where=fechaobservacion >= '${d}T00:00:00' AND fechaobservacion < '${next}T00:00:00'" \
    --data-urlencode "\$limit=100000" -o tmp.csv
  if [ ! -f "$OUT" ]; then cat tmp.csv > "$OUT"; else tail -n +2 tmp.csv >> "$OUT"; fi
  echo "$d -> $(($(wc -l < tmp.csv)-1)) filas"
  d=$next
done
rm -f tmp.csv
echo "Total filas: $(($(wc -l < "$OUT")-1))"
