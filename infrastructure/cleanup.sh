#!/bin/bash
# ===================================================
# CLEANUP SCRIPT - Delete all AWS resources
# Run this to avoid ongoing charges!
# ===================================================

REGION="us-east-1"
PROJECT_NAME="devops-portfolio"

echo "🧹 Starting cleanup of $PROJECT_NAME resources..."
echo ""

# Load saved IDs if available
source setup_network_ids.env 2>/dev/null
source setup_security_ids.env 2>/dev/null
source setup_scaling_ids.env 2>/dev/null

# Step 1: Delete Auto Scaling Group
echo "1️⃣ Deleting Auto Scaling Group..."
aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name $PROJECT_NAME-asg \
    --force-delete \
    --region $REGION 2>/dev/null
echo "   Waiting for ASG termination..."
sleep 30

# Step 2: Delete Launch Template
echo "2️⃣ Deleting Launch Template..."
aws ec2 delete-launch-template \
    --launch-template-name $PROJECT_NAME-lt \
    --region $REGION 2>/dev/null

# Step 3: Delete Load Balancer
echo "3️⃣ Deleting Load Balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names $PROJECT_NAME-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region $REGION 2>/dev/null)
if [ "$ALB_ARN" != "None" ] && [ -n "$ALB_ARN" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION
    echo "   Waiting for ALB deletion..."
    sleep 60
fi

# Step 4: Delete Target Group
echo "4️⃣ Deleting Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups --names $PROJECT_NAME-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region $REGION 2>/dev/null)
if [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
    aws elbv2 delete-target-group --target-group-arn $TG_ARN --region $REGION
fi

# Step 5: Delete RDS Instance
echo "5️⃣ Deleting RDS Instance (this takes several minutes)..."
aws rds delete-db-instance \
    --db-instance-identifier $PROJECT_NAME-db \
    --skip-final-snapshot \
    --region $REGION 2>/dev/null
echo "   RDS deletion initiated. Waiting..."
sleep 120

# Step 6: Delete DB Subnet Group
echo "6️⃣ Deleting DB Subnet Group..."
aws rds delete-db-subnet-group \
    --db-subnet-group-name $PROJECT_NAME-subnet-group \
    --region $REGION 2>/dev/null

# Get VPC ID
if [ -z "$VPC_ID" ]; then
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$PROJECT_NAME-vpc" --query 'Vpcs[0].VpcId' --output text --region $REGION 2>/dev/null)
fi

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    # Step 7: Delete Security Groups
    echo "7️⃣ Deleting Security Groups..."
    for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text --region $REGION); do
        aws ec2 delete-security-group --group-id $sg --region $REGION 2>/dev/null
    done

    # Step 8: Delete Subnets
    echo "8️⃣ Deleting Subnets..."
    for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text --region $REGION); do
        aws ec2 delete-subnet --subnet-id $subnet --region $REGION 2>/dev/null
    done

    # Step 9: Delete Internet Gateway
    echo "9️⃣ Deleting Internet Gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --region $REGION)
    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION 2>/dev/null
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION 2>/dev/null
    fi

    # Step 10: Delete Route Tables
    echo "🔟 Deleting Route Tables..."
    for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text --region $REGION); do
        aws ec2 delete-route-table --route-table-id $rt --region $REGION 2>/dev/null
    done

    # Step 11: Delete VPC
    echo "1️⃣1️⃣ Deleting VPC..."
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null
fi

# Step 12: Delete CloudWatch Resources
echo "1️⃣2️⃣ Deleting CloudWatch Dashboard and Alarms..."
aws cloudwatch delete-dashboards --dashboard-names $PROJECT_NAME-dashboard --region $REGION 2>/dev/null
aws cloudwatch delete-alarms --alarm-names $PROJECT_NAME-high-cpu $PROJECT_NAME-unhealthy-targets --region $REGION 2>/dev/null

# Cleanup local env files
echo "🗑️ Cleaning up local files..."
rm -f setup_*.env

echo ""
echo "========================================"
echo "✅ Cleanup Complete!"
echo "========================================"
echo ""
echo "Note: RDS deletion may still be in progress."
echo "Check AWS Console to confirm all resources are deleted."
echo "Billing: https://console.aws.amazon.com/billing/"
