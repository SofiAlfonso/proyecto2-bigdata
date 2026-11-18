#!/bin/bash
# Punto 2, base de datos: RDS MariaDB privada "bd-estaciones" con la base "ideam".
# Donde: terminal del Learner Lab (o CloudShell), despues de infra/01_red.sh. Tarda 5 a 15 min.
# Uso:   bash 02_fuentes_datos/infra/03_rds.sh
# Pide la clave maestra (8 a 41 caracteres, sin / " @ ni espacios); no se guarda en ningun archivo.
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""

read -rsp "Clave maestra de RDS: " DB_PASSWORD; echo

VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
RDS_SG=$(aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=rds-mariadb \
  --query 'SecurityGroups[0].GroupId' --output text)

# Grupo de subredes con las subredes por defecto (solo se crea si no existe)
if ! aws rds describe-db-subnet-groups --db-subnet-group-name rds-ideam-subnets >/dev/null 2>&1; then
  # shellcheck disable=SC2046  # la lista de subredes se separa en palabras a proposito
  aws rds create-db-subnet-group --db-subnet-group-name rds-ideam-subnets \
    --db-subnet-group-description "Subredes de la VPC por defecto" \
    --subnet-ids $(aws ec2 describe-subnets \
      --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true \
      --query 'Subnets[].SubnetId' --output text) \
    --query DBSubnetGroup.DBSubnetGroupName --output text
fi

# Ultima version menor de MariaDB 11.8, la misma rama de la evidencia (11.8.9)
ENGINE_VERSION=$(aws rds describe-db-engine-versions --engine mariadb \
  --query "DBEngineVersions[?starts_with(EngineVersion, '11.8')].EngineVersion | [-1]" --output text)

# Restricciones del Learner Lab: db.t3.micro, Single-AZ, <=100 GB, sin monitoreo mejorado
aws rds create-db-instance \
  --db-instance-identifier bd-estaciones \
  --engine mariadb --engine-version "$ENGINE_VERSION" \
  --db-instance-class db.t3.micro \
  --allocated-storage 20 --storage-type gp2 \
  --db-name ideam \
  --master-username admin --master-user-password "$DB_PASSWORD" \
  --db-subnet-group-name rds-ideam-subnets \
  --vpc-security-group-ids "$RDS_SG" \
  --no-publicly-accessible --no-multi-az \
  --backup-retention-period 0 --monitoring-interval 0 \
  --no-enable-performance-insights --no-deletion-protection \
  --query 'DBInstance.DBInstanceStatus' --output text

echo "Esperando a que la base quede disponible..."
aws rds wait db-instance-available --db-instance-identifier bd-estaciones
echo "Endpoint (va en ~/.my.cnf de la EC2):"
aws rds describe-db-instances --db-instance-identifier bd-estaciones \
  --query 'DBInstances[0].Endpoint.Address' --output text
