#!/bin/bash

# Load IDs
if [ -f "setup_network_ids.env" ]; then
    source setup_network_ids.env
else
    echo "Error: setup_network_ids.env not found."
    exit 1
fi

if [ -f "setup_security_ids.env" ]; then
    source setup_security_ids.env
else
    echo "Error: setup_security_ids.env not found."
    exit 1
fi

PROJECT_NAME="devops-portfolio"
DB_NAME="devopsdb"
DB_USER="admin"
DB_PASS="@2005Unmesh34!" # Change this!

echo "Creating DB Subnet Group..."
aws rds create-db-subnet-group \
    --db-subnet-group-name $PROJECT_NAME-subnet-group \
    --db-subnet-group-description "Subnet group for RDS" \
    --subnet-ids $PRIV_SUB_1 $PRIV_SUB_2 \
    --region $REGION

echo "Creating RDS MySQL Instance (This may take 10-15 minutes)..."
# Using db.t3.micro for Free Tier eligibility (as of 2024/2025)
aws rds create-db-instance \
    --db-instance-identifier $PROJECT_NAME-db \
    --db-name $DB_NAME \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username $DB_USER \
    --master-user-password $DB_PASS \
    --allocated-storage 20 \
    --vpc-security-group-ids $RDS_SG_ID \
    --db-subnet-group-name $PROJECT_NAME-subnet-group \
    --no-publicly-accessible \
    --backup-retention-period 0 \
    --multi-az false \
    --auto-minor-version-upgrade \
    --region $REGION | grep "DBInstanceIdentifier"

# Note: Multi-AZ is disabled for Free Tier cost savings, but can be enabled for HA.
echo "RDS Instance creation initiated."

echo "Waiting for RDS endpoint (this script might finish before it's ready, check console or wait)..."
echo "You can check status with: aws rds describe-db-instances --db-instance-identifier $PROJECT_NAME-db --query 'DBInstances[0].Endpoint.Address'"

echo "DB_INSTANCE_ID=$PROJECT_NAME-db" > setup_database_ids.env
echo "DB_NAME=$DB_NAME" >> setup_database_ids.env
echo "DB_USER=$DB_USER" >> setup_database_ids.env
echo "DB_PASS=$DB_PASS" >> setup_database_ids.env

echo "Phase 3 Complete: RDS provisioning started."
