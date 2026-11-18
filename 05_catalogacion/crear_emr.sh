#!/bin/bash
# Punto 5, EMR: cluster con Hive y Spark que usa el catalogo de Glue como metastore.
# Con esta configuracion Hive y SparkSQL ven "ideam_trusted" directamente, sin el
# --hiveconf ...AWSGlueDataCatalogHiveClientFactory que se paso a mano en la evidencia.
# Donde: terminal del Learner Lab (o CloudShell), despues de crear_crawler.sh.
# Uso:   bash 05_catalogacion/crear_emr.sh <nombre-del-bucket>
# COSTO: es lo mas caro del proyecto. Se apaga solo tras 1 h sin uso; terminarlo al acabar:
#   aws emr terminate-clusters --cluster-ids <cluster-id>
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
BUCKET_NAME="${1:?Uso: crear_emr.sh <nombre-del-bucket>}"
TIPO="${TIPO:-m5.xlarge}"

RELEASE=$(aws emr list-release-labels --filters Prefix=emr-7 --query 'ReleaseLabels' --output text \
  | tr '\t' '\n' | sort -V | tail -n 1)
VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=availability-zone,Values=us-east-1a Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)
GLUE='{"hive.metastore.client.factory.class":"com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"}'

# 1 maestro + 1 nodo core. Roles por defecto de EMR (existen en el Learner Lab).
CLUSTER_ID=$(aws emr create-cluster --name emr-ideam --release-label "$RELEASE" \
  --applications Name=Hadoop Name=Hive Name=Spark \
  --instance-type "$TIPO" --instance-count 2 \
  --use-default-roles --ec2-attributes "SubnetId=$SUBNET_ID" \
  --configurations "[{\"Classification\":\"hive-site\",\"Properties\":$GLUE},{\"Classification\":\"spark-hive-site\",\"Properties\":$GLUE}]" \
  --log-uri "s3://$BUCKET_NAME/logs/emr/" \
  --auto-termination-policy IdleTimeout=3600 \
  --query ClusterId --output text)

echo "Cluster $CLUSTER_ID ($RELEASE) creandose, tarda unos 10 min..."
aws emr wait cluster-running --cluster-id "$CLUSTER_ID"
echo "Listo: $CLUSTER_ID"
