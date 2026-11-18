-- Carga el Catalogo Nacional de Estaciones del IDEAM (hp9r-jxuu) en RDS MariaDB.
-- Se guarda "tal cual" (zona raw): sin llave primaria sobre codigo, porque la fuente
-- trae cada estacion repetida 2 o 4 veces. La limpieza se hace en la Fase 4.
USE ideam;

DROP TABLE IF EXISTS estaciones;
CREATE TABLE estaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(20),
  nombre VARCHAR(150),
  categoria VARCHAR(50),
  tecnologia VARCHAR(80),
  estado VARCHAR(30),
  departamento VARCHAR(80),
  municipio VARCHAR(80),
  altitud DECIMAL(8,2),
  latitud DECIMAL(12,9),
  longitud DECIMAL(12,9),
  fecha_instalacion VARCHAR(10),
  fecha_suspension VARCHAR(10),
  area_operativa VARCHAR(100),
  corriente VARCHAR(80),
  area_hidrografica VARCHAR(50),
  zona_hidrografica VARCHAR(80),
  subzona_hidrografica VARCHAR(100),
  entidad VARCHAR(150)
) CHARACTER SET utf8mb4;

LOAD DATA LOCAL INFILE 'estaciones.csv' INTO TABLE estaciones
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (codigo, nombre, categoria, tecnologia, estado, departamento, municipio,
   altitud, latitud, longitud, fecha_instalacion, fecha_suspension,
   area_operativa, corriente, area_hidrografica, zona_hidrografica,
   subzona_hidrografica, entidad);

SELECT COUNT(*) AS filas, COUNT(DISTINCT codigo) AS estaciones_distintas FROM estaciones;
