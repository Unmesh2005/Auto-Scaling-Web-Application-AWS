#!/bin/bash

# Load Network Resource IDs
if [ -f "setup_network_ids.env" ]; then
    source setup_network_ids.env
else
    echo "Error: setup_network_ids.env not found. Run 01-network.sh first."
    exit 1
fi

PROJECT_NAME="devops-portfolio"
MY_IP=$(curl -s http://checkip.amazonaws.com)

echo "Detected your IP as: $MY_IP"

echo "Creating Application Load Balancer Security Group..."
ALB_SG_ID=$(aws ec2 create-security-group --group-name $PROJECT_NAME-alb-sg --description "ALB Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)
aws ec2 create-tags --resources $ALB_SG_ID --tags Key=Name,Value=$PROJECT_NAME-alb-sg --region $REGION
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
echo "ALB SG Created: $ALB_SG_ID"

echo "Creating Web Server Security Group..."
WEB_SG_ID=$(aws ec2 create-security-group --group-name $PROJECT_NAME-web-sg --description "Web Server Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)
aws ec2 create-tags --resources $WEB_SG_ID --tags Key=Name,Value=$PROJECT_NAME-web-sg --region $REGION
# Allow HTTP from ALB SG
aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID --region $REGION
# Allow SSH from My IP
aws ec2 authorize-security-group-ingress --group-id $WEB_SG_ID --protocol tcp --port 22 --cidr $MY_IP/32 --region $REGION
echo "Web SG Created: $WEB_SG_ID"

echo "Creating RDS Security Group..."
RDS_SG_ID=$(aws ec2 create-security-group --group-name $PROJECT_NAME-rds-sg --description "RDS Security Group" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)
aws ec2 create-tags --resources $RDS_SG_ID --tags Key=Name,Value=$PROJECT_NAME-rds-sg --region $REGION
# Allow MySQL from Web SG
aws ec2 authorize-security-group-ingress --group-id $RDS_SG_ID --protocol tcp --port 3306 --source-group $WEB_SG_ID --region $REGION
echo "RDS SG Created: $RDS_SG_ID"

echo "Saving Security Group IDs..."
echo "ALB_SG_ID=$ALB_SG_ID" > setup_security_ids.env
echo "WEB_SG_ID=$WEB_SG_ID" >> setup_security_ids.env
echo "RDS_SG_ID=$RDS_SG_ID" >> setup_security_ids.env

echo "Phase 2 Complete: Security Groups Configured."
