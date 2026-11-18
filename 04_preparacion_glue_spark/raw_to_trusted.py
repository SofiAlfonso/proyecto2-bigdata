"""
Job de AWS Glue (Spark): zona raw -> zona trusted.
Lee los 3 conjuntos de datos crudos desde S3, los limpia y los guarda en Parquet.
"""
import sys
from pyspark.sql import functions as F
from pyspark.sql.window import Window

BUCKET = "s3://proyecto2-datalake-sofi22"


# ---------- Funciones de limpieza ----------

def texto_normalizado(col):
    """MAYUSCULAS, sin tildes, sin comas ni espacios sobrantes. Bogota queda siempre como 'BOGOTA D.C.'"""
    limpio = F.upper(F.trim(F.translate(F.regexp_replace(col, ",", ""),
                                        "ÁÉÍÓÚÜÑáéíóúüñ", "AEIOUUNaeiouun")))
    return F.when(limpio.startswith("BOGOTA"), "BOGOTA D.C.").otherwise(limpio)


def vacio_a_nulo(col):
    return F.when(F.trim(F.col(col)) == "", None).otherwise(F.col(col))


def limpiar_catalogo(df):
    for c in df.columns:
        df = df.withColumn(c, vacio_a_nulo(c))
    df = (df
          .withColumn("codigo_estacion", F.lpad("codigo", 10, "0"))
          .withColumn("altitud", F.col("altitud").cast("double"))
          .withColumn("latitud", F.col("latitud").cast("double"))
          .withColumn("longitud", F.col("longitud").cast("double"))
          .withColumn("fecha_instalacion", F.to_date("fecha_instalacion", "dd/MM/yyyy"))
          .withColumn("fecha_suspension", F.to_date("fecha_suspension", "dd/MM/yyyy"))
          .withColumn("departamento", texto_normalizado(F.col("departamento")))
          .withColumn("municipio", texto_normalizado(F.col("municipio"))))
    # Una fila por estacion: se prefiere la fila cuyo codigo original tenia 10 digitos.
    ventana = Window.partitionBy("codigo_estacion").orderBy(F.length("codigo").desc(), F.col("id").cast("int"))
    return (df.withColumn("n", F.row_number().over(ventana))
              .filter(F.col("n") == 1)
              .drop("n", "id", "codigo"))


def limpiar_temperatura(df):
    df = (df
          .withColumn("codigo_estacion", F.lpad("codigoestacion", 10, "0"))
          .withColumn("fecha", F.to_timestamp("fechaobservacion", "yyyy-MM-dd'T'HH:mm:ss.SSS"))
          .withColumn("valor_c", F.col("valorobservado").cast("double"))
          .withColumn("latitud", F.col("latitud").cast("double"))
          .withColumn("longitud", F.col("longitud").cast("double"))
          .withColumn("departamento", texto_normalizado(F.col("departamento")))
          .withColumn("municipio", texto_normalizado(F.col("municipio")))
          # Nulos y valores fuera de rango (error de sensor) quedan descartados.
          .filter(F.col("valor_c").between(-10, 45))
          .filter(F.col("fecha").isNotNull())
          .withColumn("anio", F.year("fecha"))
          .withColumn("mes", F.month("fecha"))
          .withColumn("dia", F.dayofmonth("fecha"))
          .withColumn("hora", F.hour("fecha"))
          .dropDuplicates(["codigo_estacion", "fecha", "codigosensor"]))
    return df.select(
        "codigo_estacion", F.col("codigosensor").alias("codigo_sensor"),
        "fecha", "anio", "mes", "dia", "hora", "valor_c",
        F.col("nombreestacion").alias("nombre_estacion"),
        "departamento", "municipio",
        F.col("zonahidrografica").alias("zona_hidrografica"),
        "latitud", "longitud")


def limpiar_recientes(df):
    df = (df
          .withColumn("codigo_estacion", F.lpad("codigoestacion", 10, "0"))
          .withColumn("fecha", F.to_timestamp("fechaobservacion", "yyyy-MM-dd'T'HH:mm:ss.SSS"))
          .withColumn("valor", F.col("valorobservado").cast("double"))
          .withColumn("latitud", F.col("latitud").cast("double"))
          .withColumn("longitud", F.col("longitud").cast("double"))
          .withColumn("departamento", texto_normalizado(F.col("departamento")))
          .withColumn("municipio", texto_normalizado(F.col("municipio")))
          .filter(F.col("fecha").isNotNull() & F.col("valor").isNotNull())
          .dropDuplicates(["codigo_estacion", "fecha", "codigosensor"]))
    return df.select(
        "codigo_estacion", F.col("codigosensor").alias("codigo_sensor"),
        F.col("descripcionsensor").alias("descripcion_sensor"),
        "fecha", "valor", F.col("unidadmedida").alias("unidad"),
        F.col("nombreestacion").alias("nombre_estacion"),
        "departamento", "municipio",
        F.col("zonahidrografica").alias("zona_hidrografica"),
        "latitud", "longitud", "entidad")


# ---- EJECUCION ----
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

args = getResolvedOptions(sys.argv, ["JOB_NAME"])
glue = GlueContext(SparkContext.getOrCreate())
spark = glue.spark_session
job = Job(glue)
job.init(args["JOB_NAME"], args)

# 1) Catalogo de estaciones (TSV exportado de RDS)
cat_raw = spark.read.option("header", True).option("sep", "\t").csv(f"{BUCKET}/raw/catalogo_estaciones/")
cat = limpiar_catalogo(cat_raw)
cat.write.mode("overwrite").parquet(f"{BUCKET}/trusted/catalogo_estaciones/")
print("CATALOGO  raw:", cat_raw.count(), " trusted:", cat.count())

# 2) Temperatura historica (CSV de la EC2)
temp_raw = spark.read.option("header", True).csv(f"{BUCKET}/raw/temperatura_historica/")
temp = limpiar_temperatura(temp_raw)
temp.write.mode("overwrite").parquet(f"{BUCKET}/trusted/temperatura/")
print("TEMPERATURA  raw:", temp_raw.count(), " trusted:", temp.count())

# 3) Estaciones recientes (CSV de la API; varios archivos, uno por corrida)
rec_raw = spark.read.option("header", True).csv(f"{BUCKET}/raw/estaciones_recientes/")
rec = limpiar_recientes(rec_raw)
rec.write.mode("overwrite").parquet(f"{BUCKET}/trusted/estaciones_recientes/")
print("RECIENTES  raw:", rec_raw.count(), " trusted:", rec.count())

job.commit()
