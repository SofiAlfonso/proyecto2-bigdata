#!/bin/bash
# Punto 2, red: grupos de seguridad de la EC2 fuente y de RDS, en la VPC por defecto.
# Donde: terminal del Learner Lab (o CloudShell), desde la raiz del repo.
# Uso:   bash 02_fuentes_datos/infra/01_red.sh
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""

VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)

# EC2: sin reglas de entrada (se entra con Session Manager); la salida queda libre por defecto
EC2_SG=$(aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name fuente-archivos-sg \
  --description "EC2 fuente-archivos, sin entrada" --query GroupId --output text)

# RDS: solo acepta MariaDB (3306) desde la EC2
RDS_SG=$(aws ec2 create-security-group --vpc-id "$VPC_ID" --group-name rds-mariadb \
  --description "RDS bd-estaciones, 3306 desde la EC2" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id "$RDS_SG" \
  --protocol tcp --port 3306 --source-group "$EC2_SG" --query Return --output text

echo "EC2_SG=$EC2_SG  RDS_SG=$RDS_SG"
