#!/bin/bash
# Punto 2, archivos: lanza la EC2 "fuente-archivos". Su user data es setup_ec2.sh con
# REPO_GITHUB, RAMA y BUCKET_NAME de .env puestos al inicio.
# Donde: terminal del Learner Lab (o CloudShell), despues de infra/01_red.sh.
# Uso:   bash 02_fuentes_datos/infra/02_ec2.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f "$RAIZ/.env" ] || { echo "Falta $RAIZ/.env: cp env.ejemplo .env y ajustarlo"; exit 1; }
# shellcheck source=/dev/null
source "$RAIZ/.env"
export AWS_DEFAULT_REGION="${AWS_REGION:?Falta AWS_REGION en .env}" AWS_PAGER=""
: "${REPO_GITHUB:?Falta REPO_GITHUB en .env}" "${RAMA:?Falta RAMA en .env}" "${BUCKET_NAME:?Falta BUCKET_NAME en .env}"

# User data = variables de .env + setup_ec2.sh
USER_DATA=$(mktemp)
{
  echo '#!/bin/bash'
  printf 'REPO_GITHUB=%q\nRAMA=%q\nBUCKET_NAME=%q\n' "$REPO_GITHUB" "$RAMA" "$BUCKET_NAME"
  tail -n +2 "$RAIZ/02_fuentes_datos/setup_ec2.sh"
} > "$USER_DATA"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
EC2_SG=$(aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=fuente-archivos-sg \
  --query 'SecurityGroups[0].GroupId' --output text)
# Subred por defecto de la zona "a", para no caer en una zona sin t3.micro
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=availability-zone,Values="${AWS_REGION}a" Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)

# LabInstanceProfile da permisos de S3 (para ingesta.sh) y de Session Manager. Sin llave: no hay SSH.
aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$EC2_SG" \
  --associate-public-ip-address \
  --iam-instance-profile Name=LabInstanceProfile \
  --user-data "file://$USER_DATA" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fuente-archivos}]' \
  --query 'Instances[0].InstanceId' --output text
rm -f "$USER_DATA"
