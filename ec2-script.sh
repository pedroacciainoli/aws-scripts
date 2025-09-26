#!/bin/bash

# Solicitar credenciais AWS do usuário
read -p "Digite seu AWS Access Key ID: " ACCESS_KEY_ID
read -p "Digite seu AWS Secret Access Key: " SECRET_ACCESS_KEY
read -p "Digite seu Session Token (pressione Enter se não tiver): " SESSION_TOKEN
read -p "Digite a região (padrão us-west-2): " REGION
REGION=${REGION:-us-west-2}  
OUTPUT_FORMAT="json"

# Configurar AWS CLI (opcional)
aws configure set aws_access_key_id "$ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$SECRET_ACCESS_KEY"
aws configure set region "$REGION"
aws configure set output "$OUTPUT_FORMAT"

# Exportar variáveis de ambiente para AWS CLI usar
export AWS_ACCESS_KEY_ID="$ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$SECRET_ACCESS_KEY"
export AWS_SESSION_TOKEN="$SESSION_TOKEN"
export AWS_DEFAULT_REGION="$REGION"

echo "Região selecionada: $REGION"

# Buscar latest Amazon Linux 2023 AMI
AMI_ID=$(aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=architecture,Values=x86_64" "Name=state,Values=available" \
  --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
  --output text)

echo "AMI escolhida: $AMI_ID"

# Configurar variáveis do projeto
VPC_NAME="VPC"
SUBNET_NAME="Public-Subnet"
IGW_NAME="IGW"
SG_NAME="SG"
KEY_NAME="Chave"
INSTANCE_NAME="Web-Server"

# Criar VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$VPC_NAME}]" \
  --query 'Vpc.VpcId' --output text)

echo "VPC criada: $VPC_ID"

# Criar Subnet
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone ${REGION}a \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$SUBNET_NAME}]" \
  --query 'Subnet.SubnetId' --output text)

echo "Subnet criada: $SUBNET_ID"

# Habilitar IP público na Subnet
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch

# Criar e associar Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$IGW_NAME}]" --query 'InternetGateway.InternetGatewayId' --output text)
echo "IGW criado: $IGW_ID"

aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
echo "IGW associado à VPC"

# Atualizar Route Table
RTB_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[0].RouteTableId' --output text)

aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $RTB_ID
echo "Route Table configurada."

# Criar Security Group e liberara as portas SSH e HTTP
SG_ID=$(aws ec2 create-security-group --group-name $SG_NAME --description "SG para EC2" --vpc-id $VPC_ID --query 'GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "Security Group configurado: $SG_ID"

# Criar Key Pair
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text > ${KEY_NAME}.pem
chmod 400 ${KEY_NAME}.pem
echo "Key pair criada: ${KEY_NAME}.pem"

# User Data para instalação e inicialização do Apache
USER_DATA="#!/bin/bash
yum -y install httpd
systemctl enable --now httpd
echo '<html><body><h1>Script executado com sucesso!</h1></body></html>' > /var/www/html/index.html"

# Criar instância EC2
INSTANCE_ID=$(aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro --key-name $KEY_NAME --security-group-ids $SG_ID --subnet-id $SUBNET_ID --associate-public-ip-address --user-data "$USER_DATA" --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" --query 'Instances[0].InstanceId' --output text)

echo "Aguardando inicialização da instância..."
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID

# Obter IP público
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instância EC2 criada: $INSTANCE_ID"
echo "Endereço público: $PUBLIC_IP"
echo "------------------------------------------------"
echo "Para acessar via SSH:"
echo "ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo "Acesse http://${PUBLIC_IP}/ "
