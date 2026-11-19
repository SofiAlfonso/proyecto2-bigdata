"""
Punto 8: aplicacion Streamlit que consume la API (API Gateway + Lambda) y grafica con matplotlib
las respuestas guardadas en la zona refined del data lake.
La URL de la API se lee de la variable API_URL o del archivo .env junto a este script.
Ejecucion en la EC2: bash iniciar_streamlit.sh <API_URL>
"""
import os
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import requests
import streamlit as st


def leer_api_url():
    if os.environ.get("API_URL"):
        return os.environ["API_URL"].rstrip("/")
    env = Path(__file__).with_name(".env")
    if env.exists():
        for linea in env.read_text().splitlines():
            if linea.startswith("API_URL="):
                return linea.split("=", 1)[1].strip().rstrip("/")
    st.error("Falta API_URL: ejecutar con iniciar_streamlit.sh <API_URL>")
    st.stop()


API_URL = leer_api_url()

# Por consulta: titulo, tipo de grafica, como armar la etiqueta, columnas a graficar y eje
CONSULTAS = {
    "q1": ("Departamentos por temperatura promedio", "barh",
           lambda d: d["departamento"], ["temp_promedio"], "Temperatura promedio (°C)"),
    "q2a": ("Los 10 municipios más cálidos", "barh",
            lambda d: d["municipio"] + " (" + d["departamento"] + ")", ["temp_promedio"], "Temperatura promedio (°C)"),
    "q2b": ("Los 10 municipios más fríos", "barh",
            lambda d: d["municipio"] + " (" + d["departamento"] + ")", ["temp_promedio"], "Temperatura promedio (°C)"),
    "q3": ("Temperatura mes a mes (abril a junio de 2025)", "line",
           lambda d: d["mes"].astype(str), ["temp_minima", "temp_promedio", "temp_maxima"], "Temperatura (°C)"),
    "q4": ("Temperatura promedio por hora del día", "line",
           lambda d: d["hora"].astype(str), ["temp_promedio"], "Temperatura promedio (°C)"),
    "q5": ("Temperatura promedio por rango de altitud", "bar",
           lambda d: d["rango_altitud"], ["temp_promedio"], "Temperatura promedio (°C)"),
    "q6": ("Mediciones por categoría y tecnología de estación", "barh",
           lambda d: d["categoria"] + " / " + d["tecnologia"], ["mediciones"], "Mediciones"),
    "q7": ("Las 10 estaciones con menos mediciones", "barh",
           lambda d: d["nombre"] + " (" + d["codigo_estacion"].astype(str) + ")", ["mediciones"], "Mediciones"),
}


@st.cache_data(ttl=300)
def pedir(ruta):
    r = requests.get(f"{API_URL}{ruta}", timeout=15)
    r.raise_for_status()
    return r.json()


def graficar(datos, tipo, etiqueta, columnas, eje):
    fig, ax = plt.subplots(figsize=(9, max(3.5, 0.4 * len(datos)) if tipo == "barh" else 4.5))
    x = etiqueta(datos)
    if tipo == "barh":
        ax.barh(x, datos[columnas[0]], color="#378ADD")
        ax.invert_yaxis()                       # el primero de la tabla queda arriba
        ax.set_xlabel(eje)
    elif tipo == "bar":
        ax.bar(x, datos[columnas[0]], color="#378ADD")
        ax.set_ylabel(eje)
    else:
        for col in columnas:
            ax.plot(x, datos[col], marker="o", label=col.replace("_", " "))
        ax.set_ylabel(eje)
        if len(columnas) > 1:
            ax.legend()
    ax.grid(axis="x" if tipo == "barh" else "y", alpha=0.3)
    fig.tight_layout()
    return fig


st.set_page_config(page_title="Temperatura IDEAM", layout="wide")
st.title("Temperatura del aire en Colombia (IDEAM), abril a junio de 2025")
st.caption(f"Datos servidos por API Gateway + Lambda desde la zona refined del data lake: {API_URL}")

disponibles = [c for c in pedir("/consultas")["consultas"] if c in CONSULTAS]
if not disponibles:
    st.warning("La API no tiene consultas disponibles. Ejecutar generar_refined.sh.")
    st.stop()

elegida = st.sidebar.radio("Pregunta", disponibles, format_func=lambda c: f"{c.upper()}. {CONSULTAS[c][0]}")
titulo, tipo, etiqueta, columnas, eje = CONSULTAS[elegida]
datos = pd.DataFrame(pedir(f"/consultas/{elegida}")["filas"])

st.subheader(f"{elegida.upper()}. {titulo}")
st.pyplot(graficar(datos, tipo, etiqueta, columnas, eje))
st.dataframe(datos, hide_index=True, width="stretch")
