#!/bin/bash

# Configuration
VPC_CIDR="10.0.0.0/16"
PUB_SUBNET_1_CIDR="10.0.1.0/24"
PUB_SUBNET_2_CIDR="10.0.2.0/24"
PRIV_SUBNET_1_CIDR="10.0.11.0/24"
PRIV_SUBNET_2_CIDR="10.0.12.0/24"
REGION="us-east-1"
AZ1="us-east-1a"
AZ2="us-east-1b"
PROJECT_NAME="devops-portfolio"

echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.VpcId' --output text --region $REGION)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$PROJECT_NAME-vpc --region $REGION
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $REGION
echo "VPC Created: $VPC_ID"

echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region $REGION)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$PROJECT_NAME-igw --region $REGION
echo "IGW Created: $IGW_ID"

echo "Creating Public Subnets..."
PUB_SUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUB_SUBNET_1_CIDR --availability-zone $AZ1 --query 'Subnet.SubnetId' --output text --region $REGION)
aws ec2 create-tags --resources $PUB_SUB_1 --tags Key=Name,Value=$PROJECT_NAME-public-subnet-1 --region $REGION
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB_1 --map-public-ip-on-launch --region $REGION

PUB_SUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUB_SUBNET_2_CIDR --availability-zone $AZ2 --query 'Subnet.SubnetId' --output text --region $REGION)
aws ec2 create-tags --resources $PUB_SUB_2 --tags Key=Name,Value=$PROJECT_NAME-public-subnet-2 --region $REGION
aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB_2 --map-public-ip-on-launch --region $REGION

echo "Creating Private Subnets..."
PRIV_SUB_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIV_SUBNET_1_CIDR --availability-zone $AZ1 --query 'Subnet.SubnetId' --output text --region $REGION)
aws ec2 create-tags --resources $PRIV_SUB_1 --tags Key=Name,Value=$PROJECT_NAME-private-subnet-1 --region $REGION

PRIV_SUB_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRIV_SUBNET_2_CIDR --availability-zone $AZ2 --query 'Subnet.SubnetId' --output text --region $REGION)
aws ec2 create-tags --resources $PRIV_SUB_2 --tags Key=Name,Value=$PROJECT_NAME-private-subnet-2 --region $REGION

echo "Creating Public Route Table..."
PUB_RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text --region $REGION)
aws ec2 create-tags --resources $PUB_RT_ID --tags Key=Name,Value=$PROJECT_NAME-public-rt --region $REGION
aws ec2 create-route --route-table-id $PUB_RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION

echo "Associating Public Subnets with Public Route Table..."
aws ec2 associate-route-table --subnet-id $PUB_SUB_1 --route-table-id $PUB_RT_ID --region $REGION
aws ec2 associate-route-table --subnet-id $PUB_SUB_2 --route-table-id $PUB_RT_ID --region $REGION

# Note: Private subnets use the default local route table unless NAT is added.
# For this cost-optimized setup, RDS in private subnets doesn't need outbound internet.

echo "setup_network_ids.env created for future steps."
echo "VPC_ID=$VPC_ID" > setup_network_ids.env
echo "PUB_SUB_1=$PUB_SUB_1" >> setup_network_ids.env
echo "PUB_SUB_2=$PUB_SUB_2" >> setup_network_ids.env
echo "PRIV_SUB_1=$PRIV_SUB_1" >> setup_network_ids.env
echo "PRIV_SUB_2=$PRIV_SUB_2" >> setup_network_ids.env
echo "IGW_ID=$IGW_ID" >> setup_network_ids.env
echo "REGION=$REGION" >> setup_network_ids.env

echo "Phase 1 Complete: Network Infrastructure Ready."
