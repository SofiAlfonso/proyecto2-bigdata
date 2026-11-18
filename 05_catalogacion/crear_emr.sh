#!/bin/bash
# Punto 5, EMR: cluster con Hive y Spark que usa el catalogo de Glue como metastore.
# Con esta configuracion Hive y SparkSQL ven "ideam_trusted" directamente, sin el
# --hiveconf ...AWSGlueDataCatalogHiveClientFactory que se paso a mano en la evidencia.
# Guarda el id del cluster en EMR_CLUSTER_ID de .env.
# Donde: terminal del Learner Lab (o CloudShell), despues de crear_crawler.sh.
# Uso:   bash 05_catalogacion/crear_emr.sh
# COSTO: es lo mas caro del proyecto. Se apaga solo tras 1 h sin uso; terminarlo al acabar:
#   source .env && aws emr terminate-clusters --cluster-ids "$EMR_CLUSTER_ID"
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"
TIPO="${TIPO:-m5.xlarge}"

RELEASE=$(aws emr list-release-labels --filters Prefix=emr-7 --query 'ReleaseLabels' --output text \
  | tr '\t' '\n' | sort -V | tail -n 1)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=availability-zone,Values="${AWS_REGION}a" Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)
GLUE='{"hive.metastore.client.factory.class":"com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"}'

# Un solo nodo (el maestro hace todo, como en el diseno acordado) y sin registros en S3:
# ejecutar_hive.sh sube la salida de cada consulta por su cuenta. Roles por defecto de EMR.
CLUSTER_ID=$(aws emr create-cluster --name cluster-ideam --release-label "$RELEASE" \
  --applications Name=Hadoop Name=Hive Name=Spark \
  --instance-type "$TIPO" --instance-count 1 \
  --use-default-roles --ec2-attributes "SubnetId=$SUBNET_ID" \
  --configurations "[{\"Classification\":\"hive-site\",\"Properties\":$GLUE},{\"Classification\":\"spark-hive-site\",\"Properties\":$GLUE}]" \
  --auto-termination-policy IdleTimeout=3600 \
  --query ClusterId --output text)

# Guardar el id en .env (reemplaza el valor anterior)
if grep -q '^EMR_CLUSTER_ID=' "$RAIZ/.env"; then
  sed -i "s/^EMR_CLUSTER_ID=.*/EMR_CLUSTER_ID=$CLUSTER_ID/" "$RAIZ/.env"
else
  echo "EMR_CLUSTER_ID=$CLUSTER_ID" >> "$RAIZ/.env"
fi

echo "Cluster $CLUSTER_ID ($RELEASE) creandose, tarda unos 10 min..."
aws emr wait cluster-running --cluster-id "$CLUSTER_ID"
echo "Listo: $CLUSTER_ID (guardado en .env)"
