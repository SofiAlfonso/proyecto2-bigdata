"""
Punto 8: API de solo lectura sobre la zona refined del data lake. API Gateway (HTTP API) invoca esta Lambda.
  GET /consultas        -> ids de las consultas disponibles (q1, q2a, ...)
  GET /consultas/{id}   -> filas de s3://<bucket>/refined/consultas/{id}.csv en JSON
El bucket llega en la variable de entorno BUCKET_NAME (la pone crear_api.sh a partir de .env).
"""
import csv
import io
import json
import os
import re

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET_NAME"]
PREFIJO = "refined/consultas/"


def respuesta(codigo, cuerpo):
    return {"statusCode": codigo,
            "headers": {"Content-Type": "application/json; charset=utf-8"},
            "body": json.dumps(cuerpo, ensure_ascii=False)}


def a_numero(valor):
    """Athena entrega todo como texto en el CSV; los numeros se devuelven como numeros."""
    for tipo in (int, float):
        try:
            return tipo(valor)
        except ValueError:
            pass
    return valor


def handler(event, context):
    partes = [p for p in event.get("rawPath", "/").split("/") if p]

    if partes == ["consultas"]:
        objetos = s3.list_objects_v2(Bucket=BUCKET, Prefix=PREFIJO).get("Contents", [])
        ids = sorted(o["Key"][len(PREFIJO):-4] for o in objetos if o["Key"].endswith(".csv"))
        return respuesta(200, {"consultas": ids})

    if len(partes) == 2 and partes[0] == "consultas" and re.fullmatch(r"[a-z0-9_]+", partes[1]):
        try:
            obj = s3.get_object(Bucket=BUCKET, Key=f"{PREFIJO}{partes[1]}.csv")
        except s3.exceptions.NoSuchKey:
            return respuesta(404, {"error": f"No existe la consulta {partes[1]}"})
        lector = csv.DictReader(io.StringIO(obj["Body"].read().decode("utf-8")))
        filas = [{k: a_numero(v) for k, v in fila.items()} for fila in lector]
        return respuesta(200, {"consulta": partes[1], "filas": filas})

    return respuesta(404, {"error": "Rutas validas: /consultas y /consultas/{id}"})
