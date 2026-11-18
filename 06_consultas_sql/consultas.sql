-- Consultas analiticas descriptivas sobre la zona trusted (base ideam_trusted).
-- Se escribieron en SQL estandar para que corran igual en Athena, Hive y SparkSQL.
-- Periodo: abril a junio de 2025.

-- Q1. Departamentos ordenados por temperatura promedio (del mas calido al mas frio)
SELECT departamento,
       ROUND(AVG(valor_c), 2) AS temp_promedio,
       COUNT(*) AS mediciones
FROM temperatura
GROUP BY departamento
ORDER BY temp_promedio DESC;

-- Q2a. Los 10 municipios mas calidos (con al menos 100 mediciones)
SELECT municipio, departamento,
       ROUND(AVG(valor_c), 2) AS temp_promedio,
       COUNT(*) AS mediciones
FROM temperatura
GROUP BY municipio, departamento
HAVING COUNT(*) >= 100
ORDER BY temp_promedio DESC
LIMIT 10;

-- Q2b. Los 10 municipios mas frios (con al menos 100 mediciones)
SELECT municipio, departamento,
       ROUND(AVG(valor_c), 2) AS temp_promedio,
       COUNT(*) AS mediciones
FROM temperatura
GROUP BY municipio, departamento
HAVING COUNT(*) >= 100
ORDER BY temp_promedio ASC
LIMIT 10;

-- Q3. Temperatura promedio mes a mes (y cuantos dias distintos tienen datos)
SELECT mes,
       ROUND(AVG(valor_c), 2) AS temp_promedio,
       ROUND(MIN(valor_c), 2) AS temp_minima,
       ROUND(MAX(valor_c), 2) AS temp_maxima,
       COUNT(*) AS mediciones,
       COUNT(DISTINCT dia) AS dias_con_datos
FROM temperatura
GROUP BY mes
ORDER BY mes;

-- Q4. Temperatura promedio por hora del dia
SELECT hora,
       ROUND(AVG(valor_c), 2) AS temp_promedio,
       COUNT(*) AS mediciones
FROM temperatura
GROUP BY hora
ORDER BY hora;

-- Q5. Relacion altitud de la estacion vs temperatura promedio (une con el catalogo)
SELECT rango_altitud,
       COUNT(DISTINCT codigo_estacion) AS estaciones,
       ROUND(AVG(valor_c), 2) AS temp_promedio
FROM (
  SELECT t.codigo_estacion, t.valor_c,
         CASE WHEN c.altitud < 500  THEN '1. menos de 500 m'
              WHEN c.altitud < 1500 THEN '2. 500 a 1499 m'
              WHEN c.altitud < 2500 THEN '3. 1500 a 2499 m'
              ELSE '4. 2500 m o mas' END AS rango_altitud
  FROM temperatura t
  JOIN catalogo_estaciones c ON t.codigo_estacion = c.codigo_estacion
) x
GROUP BY rango_altitud
ORDER BY rango_altitud;

-- Q6. Categorias y tecnologias de estacion que aportan mas mediciones
SELECT c.categoria, c.tecnologia,
       COUNT(DISTINCT t.codigo_estacion) AS estaciones,
       COUNT(*) AS mediciones
FROM temperatura t
JOIN catalogo_estaciones c ON t.codigo_estacion = c.codigo_estacion
GROUP BY c.categoria, c.tecnologia
ORDER BY mediciones DESC;

-- Q7. Las 10 estaciones que reportaron menos mediciones y sus caracteristicas
SELECT t.codigo_estacion, c.nombre, c.categoria, c.tecnologia, c.departamento,
       COUNT(*) AS mediciones
FROM temperatura t
JOIN catalogo_estaciones c ON t.codigo_estacion = c.codigo_estacion
GROUP BY t.codigo_estacion, c.nombre, c.categoria, c.tecnologia, c.departamento
ORDER BY mediciones ASC
LIMIT 10;
