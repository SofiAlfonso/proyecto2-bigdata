#!/bin/bash
# Punto 2, archivos: lanza la EC2 "fuente-archivos" con setup_ec2.sh como user data.
# Donde: terminal del Learner Lab (o CloudShell), despues de infra/01_red.sh.
# Uso:   bash 02_fuentes_datos/infra/02_ec2.sh
set -euo pipefail
export AWS_DEFAULT_REGION=us-east-1 AWS_PAGER=""
cd "$(dirname "$0")/.."   # carpeta 02_fuentes_datos, donde esta setup_ec2.sh

VPC_ID=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text)
EC2_SG=$(aws ec2 describe-security-groups \
  --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=fuente-archivos-sg \
  --query 'SecurityGroups[0].GroupId' --output text)
# Subred por defecto de us-east-1a, para no caer en una zona sin t3.micro
SUBNET_ID=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC_ID" Name=availability-zone,Values=us-east-1a Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text)

# LabInstanceProfile da permisos de S3 (para ingesta.sh) y de Session Manager. Sin llave: no hay SSH.
aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$EC2_SG" \
  --associate-public-ip-address \
  --iam-instance-profile Name=LabInstanceProfile \
  --user-data file://setup_ec2.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=fuente-archivos}]' \
  --query 'Instances[0].InstanceId' --output text
