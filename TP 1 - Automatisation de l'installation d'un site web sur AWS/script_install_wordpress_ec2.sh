#!/bin/bash
#================================================================
# HEADER
#================================================================

#################################################
# 1. Create network 							#
# 2. Create private/ public subnets				#
# 3. Create internet gateway for public subnet	#
# 4. Create NAT for EC2's in public subnet		#
# 5. Generate SSH key pair 						#
# 6. Create security group (port 22 & 80)		#
# 7. Create EC2 instance						#
#################################################


#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} (https://github.com/houssembenali/) 0.0.1
#-    author          Houssem BEN ALI
#-    copyright       Copyright (c) https://github.com/houssembenali/
#-    license         GNU General Public License
#-    script_id       12345
#-	  Last revised    18/06/2021
#-
#================================================================

#================================================================
# END_OF_HEADER
#================================================================

AWS_REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')
VPC_NAME="VPC Houssem WORDPRESS"
VPC_CIDR="12.0.0.0/16"
SUBNET_PUBLIC_CIDR="12.0.1.0/24"
SUBNET_PUBLIC_AZ=$AWS_REGION"a"
SUBNET_PUBLIC_NAME="12.0.1.0 - "$AWS_REGION"a"
SUBNET_PRIVATE_CIDR="12.0.2.0/24"
SUBNET_PRIVATE_AZ=$AWS_REGION"b"
SUBNET_PRIVATE_NAME="12.0.2.0 - "$AWS_REGION"b"
CHECK_FREQUENCY=5
KEY_NAME="houssem-wordpress-key"
IMAGE_ID="ami-0d8d212151031f51c"
INSTALL_SCRIPT_NAME="script_deploiement.sh"


# Create VPC
echo "Creating VPC in preferred region..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --query 'Vpc.{VpcId:VpcId}' \
  --output text \
  --region $AWS_REGION)
echo "  VPC ID '$VPC_ID' CREATED in '$AWS_REGION' region."

# Add Name tag to VPC
aws ec2 create-tags \
  --resources $VPC_ID \
  --tags "Key=Name,Value=$VPC_NAME" \
  --region $AWS_REGION
echo "  VPC ID '$VPC_ID' NAMED as '$VPC_NAME'."

# Create Public Subnet
echo "Creating Public Subnet..."
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PUBLIC_CIDR \
  --availability-zone $SUBNET_PUBLIC_AZ \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text \
  --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PUBLIC_ID' CREATED in '$SUBNET_PUBLIC_AZ'" \
  "Availability Zone."

# Add Name tag to Public Subnet
aws ec2 create-tags \
  --resources $SUBNET_PUBLIC_ID \
  --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" \
  --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PUBLIC_ID' NAMED as" \
  "'$SUBNET_PUBLIC_NAME'."

# Create Private Subnet
echo "Creating Private Subnet..."
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PRIVATE_CIDR \
  --availability-zone $SUBNET_PRIVATE_AZ \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text \
  --region $AWS_REGION)
echo "  Subnet ID '$SUBNET_PRIVATE_ID' CREATED in '$SUBNET_PRIVATE_AZ'" \
  "Availability Zone."

# Add Name tag to Private Subnet
aws ec2 create-tags \
  --resources $SUBNET_PRIVATE_ID \
  --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" \
  --region $AWS_REGION
echo "  Subnet ID '$SUBNET_PRIVATE_ID' NAMED as '$SUBNET_PRIVATE_NAME'."

# Create Internet gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
  --output text \
  --region $AWS_REGION)
echo "  Internet Gateway ID '$IGW_ID' CREATED."

# Attach Internet gateway to your VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $AWS_REGION
echo "  Internet Gateway ID '$IGW_ID' ATTACHED to VPC ID '$VPC_ID'."

# Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.{RouteTableId:RouteTableId}' \
  --output text \
  --region $AWS_REGION)
echo "  Route Table ID '$ROUTE_TABLE_ID' CREATED."

# Create route to Internet Gateway
RESULT=$(aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region $AWS_REGION)
echo "  Route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' ADDED to" \
  "Route Table ID '$ROUTE_TABLE_ID'."

# Associate Public Subnet with Route Table
RESULT=$(aws ec2 associate-route-table  \
  --subnet-id $SUBNET_PUBLIC_ID \
  --route-table-id $ROUTE_TABLE_ID \
  --region $AWS_REGION)
echo "  Public Subnet ID '$SUBNET_PUBLIC_ID' ASSOCIATED with Route Table ID" \
  "'$ROUTE_TABLE_ID'."

# Enable Auto-assign Public IP on Public Subnet
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_PUBLIC_ID \
  --map-public-ip-on-launch \
  --region $AWS_REGION
echo "  'Auto-assign Public IP' ENABLED on Public Subnet ID" \
  "'$SUBNET_PUBLIC_ID'."

# Allocate Elastic IP Address for NAT Gateway
echo "Creating NAT Gateway..."
EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query '{AllocationId:AllocationId}' \
  --output text \
  --region $AWS_REGION)
echo "  Elastic IP address ID '$EIP_ALLOC_ID' ALLOCATED."

# Create NAT Gateway
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $SUBNET_PUBLIC_ID \
  --allocation-id $EIP_ALLOC_ID \
  --query 'NatGateway.{NatGatewayId:NatGatewayId}' \
  --output text \
  --region $AWS_REGION)
  
  
  
FORMATTED_MSG="Creating NAT Gateway ID '$NAT_GW_ID' and waiting for it to "
FORMATTED_MSG+="become available.\n    Please BE PATIENT as this can take some "
FORMATTED_MSG+="time to complete.\n    ......\n"
printf "  $FORMATTED_MSG"
FORMATTED_MSG="STATUS: %s  -  %02dh:%02dm:%02ds elapsed while waiting for NAT "
FORMATTED_MSG+="Gateway to become available..."


SECONDS=0
LAST_CHECK=0
STATE='PENDING'

until [[ $STATE == 'AVAILABLE' ]]; do
  INTERVAL=$SECONDS-$LAST_CHECK
  if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
    STATE=$(aws ec2 describe-nat-gateways \
      --nat-gateway-ids $NAT_GW_ID \
      --query 'NatGateways[*].{State:State}' \
      --output text \
      --region $AWS_REGION)
    STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
    LAST_CHECK=$SECONDS
  fi
  SECS=$SECONDS
  STATUS_MSG=$(printf "$FORMATTED_MSG" \
    $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
  printf "    $STATUS_MSG\033[0K\r"
  sleep 1
done
printf "\n    ......\n  NAT Gateway ID '$NAT_GW_ID' is now AVAILABLE.\n"



# Create route to NAT Gateway
MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true \
  --query 'RouteTables[*].{RouteTableId:RouteTableId}' \
  --output text \
  --region $AWS_REGION)
echo "  Main Route Table ID is '$MAIN_ROUTE_TABLE_ID'."

RESULT=$(aws ec2 create-route \
  --route-table-id $MAIN_ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $NAT_GW_ID \
  --region $AWS_REGION)
echo "  Route to '0.0.0.0/0' via NAT Gateway with ID '$NAT_GW_ID' ADDED to" \
  "Route Table ID '$MAIN_ROUTE_TABLE_ID'."
echo "COMPLETED"



# Creation clé SSH

if aws ec2 wait key-pair-exists --key-names $KEY_NAME --region $AWS_REGION
    then
    echo 'La clé existe déjà, on la supprime'
    aws ec2 delete-key-pair --key-name $KEY_NAME --region $AWS_REGION
fi

if test -f "$KEY_NAME.pem"
    then
    sudo rm -f $KEY_NAME.pem
fi

# Générer paire de clé : télécharger clée privé en local
aws ec2 create-key-pair \
    --key-name $KEY_NAME \
	--region $AWS_REGION \
    --query 'KeyMaterial' \
    --output text > $KEY_NAME.pem

chmod 400 $KEY_NAME.pem

echo "Clé SSH crée et prête a être utilisée"

# Création du groupe de sécurité
GROUP_ID=$(aws ec2 create-security-group \
    --group-name SSHAccess \
    --query 'GroupId' \
    --description "Security group for SSH access" \
    --vpc-id $VPC_ID\
    --output text \
    --region $AWS_REGION)

echo "Le groupe de sécurité a bien été créé avec l'id "$GROUP_ID

# Ajout des règles pour la connexion SSH

aws ec2 authorize-security-group-ingress \
    --group-id $GROUP_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
	--region $AWS_REGION

# Ajout des règles pour la connexion HTTP

aws ec2 authorize-security-group-ingress \
    --group-id $GROUP_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
	--region $AWS_REGION

echo 'Les règles de sécurité ont été ajoutées'

# Lancer l'instance EC2


INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $IMAGE_ID \
    --count 1 \
    --instance-type t2.micro \
    --key-name $KEY_NAME \
    --security-group-ids $GROUP_ID \
    --subnet-id $SUBNET_PUBLIC_ID \
    --user-data file://$INSTALL_SCRIPT_NAME \
    --query 'Instances[0].{InstanceId:InstanceId}' \
    --output text)
    
 #    | sudo  jq '.Instances[0].InstanceId' | sed -e 's/^"//' -e 's/"$//' )

	
	

echo "L'instance est lancée avec l'ID "$INSTANCE_ID

# Récupérer l'adresse IP Publique de l'instance :
INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
	--region $AWS_REGION)



echo "déploiement de l'application terminée"
echo "Veuillez effectuer les dernières étapes sur http://"$INSTANCE_IP
