# Plan maestro – Proyecto 2 Big Data (EAFIT 2026-2)

## Principios de trabajo
1. **Simplicidad ante todo:** se prefiere la solución simple que se entienda por completo a la sofisticada. Lo importante es que la integrante entienda lo que hace.
2. No se avanza de fase hasta confirmar que la anterior está terminada y con su evidencia.
3. Toda decisión importante se explica, se confirma y se alinea con la guía.
4. Respuestas cortas y claras; más detalle solo si se pide.

## Contexto
- Una sola integrante. Cuenta: AWS Academy Learner Lab (rol LabRole, sesiones limitadas, créditos limitados).
- Tema: datos climáticos de Colombia (dataset exacto por elegir).

## Arquitectura
URL pública + archivos en EC2 + RDS MariaDB -> ingesta automática -> S3 raw -> Glue/Spark -> S3 trusted -> Glue Catalog -> Athena/Hive/SparkSQL/PySpark -> S3 refined -> Streamlit + API Gateway

## Fases
| Fase | Qué se hace | Punto guía | Evidencia |
|---|---|---|---|
| 0. Preparación | Revisar Learner Lab, crear repo GitHub con carpetas 01..08, convenciones de nombres y región | Base | Consola AWS, repo con estructura |
| 1. Caso de estudio | Elegir dataset, >=5 preguntas de negocio, repartir datos en BD/archivos/URL | 1 | Descripción, preguntas, diagrama de fuentes |
| 2. Fuentes | RDS MariaDB, EC2 con archivos, URL pública | 2 | Capturas, script de carga |
| 3. Ingesta | Bucket S3 con zonas, proceso automático hacia raw | 3 | Estructura S3, código, ejecución automática |
| 4. Preparación | Job Glue + Spark raw -> trusted (Parquet) | 4 | Código, log, archivos en trusted |
| 5. Catalogación | Crawler Glue y tablas; tablas en EMR/Hive | 5 | Tablas en Glue y Hive |
| 6. SQL analítico | Athena, Hive, SparkSQL | 6 | Consultas y resultados |
| 7. PySpark | Análisis con pyspark, resultados a refined | 7 | Script/notebook y resultados |
| 8. Visualización y API | matplotlib/dash + Streamlit vía API Gateway | 8 | Capturas, URL de la API |
| 9. Cierre | Prueba de punta a punta, README reproducible, documento en OneDrive, correo al profesor, apagar recursos | Entrega | Documento, repo completo |

## Decisiones confirmadas (Fase 1)
- Periodo de análisis: **abril a junio de 2025 (3 meses)**.
- Fuentes (todas de datos.gov.co, IDEAM):
  - **RDS MariaDB:** Catálogo Nacional de Estaciones (`hp9r-jxuu`, ~38.782 filas).
  - **Archivo en EC2:** Temperatura Ambiente del Aire histórica (`sbwg-7ju4`), recorte abr–jun 2025 (~1,5 M filas, CSV).
  - **URL (API Socrata):** Datos de Estaciones de IDEAM y de Terceros (`57sv-p2fu`, ventana móvil de ~12 h, ~160 mil filas).
- Se descartó `cqmv-a99d` por ser un subconjunto redundante del catálogo.
- Limpieza prevista en Fase 4: departamentos en mayúsculas/sin tildes vs. catálogo; ceros a la izquierda en `codigoestacion`.

## Preguntas de negocio (borrador, pendiente confirmar redacción de la 7)
1. Departamentos con temperatura promedio más alta y más baja.
2. Municipio más caliente y más frío.
3. Temperatura promedio mes a mes (abr, may, jun).
4. Variación de la temperatura por hora del día.
5. Relación altitud de la estación vs. temperatura promedio (cruza catálogo).
6. Categorías/tecnologías de estación que aportan más mediciones (cruza catálogo).
7. Estaciones que reportaron menos mediciones en el periodo y sus características (categoría, tecnología, departamento).

## Estado
- [ ] Fase 0
- [ ] Fase 1 (en curso: elegir dataset)
