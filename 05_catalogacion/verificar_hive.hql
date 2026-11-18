-- Punto 5: Hive en EMR lee las tablas que crawler_trusted registro en el catalogo de Glue.
-- Uso: bash 05_catalogacion/ejecutar_hive.sh <cluster-id> <bucket> 05_catalogacion/verificar_hive.hql
-- Resultado esperado: las 3 tablas y 1453114 filas en temperatura.
SHOW DATABASES;
USE ideam_trusted;
SHOW TABLES;
DESCRIBE temperatura;
SELECT COUNT(*) AS filas FROM temperatura;
