#!/bin/bash
# Descarga el Catalogo Nacional de Estaciones del IDEAM (datos.gov.co, hp9r-jxuu).
# Se omite la columna ubicaci_n porque trae saltos de linea y repite latitud/longitud.
curl -s -g --max-time 120 -G "https://www.datos.gov.co/resource/hp9r-jxuu.csv" \
  --data-urlencode "\$select=codigo,nombre,categoria,tecnologia,estado,departamento,municipio,altitud,latitud,longitud,fecha_instalacion,fecha_suspension,area_operativa,corriente,area_hidrografica,zona_hidrografica,subzona_hidrografica,entidad" \
  --data-urlencode "\$limit=50000" -o estaciones.csv
echo "Filas: $(($(wc -l < estaciones.csv)-1))"
