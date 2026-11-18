"""
Punto 7: las mismas preguntas de 06_consultas_sql/consultas.sql, con la API de DataFrames de PySpark.
Lee las tablas del catalogo de Glue (base ideam_trusted), igual que Athena, Hive y SparkSQL.
Ejecucion en EMR:  bash 06_consultas_sql/ejecutar_emr.sh pyspark 07_pyspark/consultas.py
"""
from pyspark.sql import SparkSession, functions as F

spark = (SparkSession.builder.appName("consultas_pyspark")
         .enableHiveSupport()          # usa el catalogo de Glue configurado en el cluster
         .getOrCreate())

temp = spark.table("ideam_trusted.temperatura")
cat = spark.table("ideam_trusted.catalogo_estaciones")

# Para los joins: solo las columnas necesarias, asi no se repiten nombres (departamento, etc.)
t = temp.select("codigo_estacion", "valor_c")
c = cat.select("codigo_estacion", "nombre", "categoria", "tecnologia", "departamento", "altitud")


def mostrar(titulo, df, n=50):
    print(f"\n== {titulo}")
    df.show(n, truncate=False)


# Q1. Departamentos ordenados por temperatura promedio (del mas calido al mas frio)
q1 = (temp.groupBy("departamento")
          .agg(F.round(F.avg("valor_c"), 2).alias("temp_promedio"),
               F.count("*").alias("mediciones"))
          .orderBy(F.desc("temp_promedio")))
mostrar("Q1. Departamentos por temperatura promedio", q1)

# Q2. Municipios con al menos 100 mediciones; los 10 mas calidos y los 10 mas frios
por_municipio = (temp.groupBy("municipio", "departamento")
                     .agg(F.round(F.avg("valor_c"), 2).alias("temp_promedio"),
                          F.count("*").alias("mediciones"))
                     .filter(F.col("mediciones") >= 100))
mostrar("Q2a. Los 10 municipios mas calidos", por_municipio.orderBy(F.desc("temp_promedio")).limit(10))
mostrar("Q2b. Los 10 municipios mas frios", por_municipio.orderBy(F.asc("temp_promedio")).limit(10))

# Q3. Temperatura promedio mes a mes (y cuantos dias distintos tienen datos)
q3 = (temp.groupBy("mes")
          .agg(F.round(F.avg("valor_c"), 2).alias("temp_promedio"),
               F.round(F.min("valor_c"), 2).alias("temp_minima"),
               F.round(F.max("valor_c"), 2).alias("temp_maxima"),
               F.count("*").alias("mediciones"),
               F.countDistinct("dia").alias("dias_con_datos"))
          .orderBy("mes"))
mostrar("Q3. Temperatura mes a mes", q3)

# Q4. Temperatura promedio por hora del dia
q4 = (temp.groupBy("hora")
          .agg(F.round(F.avg("valor_c"), 2).alias("temp_promedio"),
               F.count("*").alias("mediciones"))
          .orderBy("hora"))
mostrar("Q4. Temperatura por hora del dia", q4)

# Q5. Altitud de la estacion vs temperatura promedio (une con el catalogo)
rango_altitud = (F.when(F.col("altitud") < 500, "1. menos de 500 m")
                  .when(F.col("altitud") < 1500, "2. 500 a 1499 m")
                  .when(F.col("altitud") < 2500, "3. 1500 a 2499 m")
                  .otherwise("4. 2500 m o mas"))
q5 = (t.join(c, "codigo_estacion")
       .withColumn("rango_altitud", rango_altitud)
       .groupBy("rango_altitud")
       .agg(F.countDistinct("codigo_estacion").alias("estaciones"),
            F.round(F.avg("valor_c"), 2).alias("temp_promedio"))
       .orderBy("rango_altitud"))
mostrar("Q5. Temperatura por rango de altitud", q5)

# Q6. Categorias y tecnologias de estacion que aportan mas mediciones
q6 = (t.join(c, "codigo_estacion")
       .groupBy("categoria", "tecnologia")
       .agg(F.countDistinct("codigo_estacion").alias("estaciones"),
            F.count("*").alias("mediciones"))
       .orderBy(F.desc("mediciones")))
mostrar("Q6. Mediciones por categoria y tecnologia", q6)

# Q7. Las 10 estaciones que reportaron menos mediciones y sus caracteristicas
#     (se desempata por codigo para que el resultado no cambie entre corridas)
q7 = (t.join(c, "codigo_estacion")
       .groupBy("codigo_estacion", "nombre", "categoria", "tecnologia", "departamento")
       .agg(F.count("*").alias("mediciones"))
       .orderBy("mediciones", "codigo_estacion")
       .limit(10))
mostrar("Q7. Estaciones con menos mediciones", q7)

spark.stop()
