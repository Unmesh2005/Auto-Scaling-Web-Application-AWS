# 🧹 Cleanup Guide

**⚠️ IMPORTANT**: Delete resources to avoid ongoing charges!

## Automated Cleanup Script

```bash
cd infrastructure
./cleanup.sh
```

## Manual Cleanup (In Order)

Delete resources in this specific order to avoid dependency errors:

### Step 1: Delete Auto Scaling Group
```bash
aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name devops-portfolio-asg \
    --force-delete \
    --region us-east-1
```

### Step 2: Delete Launch Template
```bash
aws ec2 delete-launch-template \
    --launch-template-name devops-portfolio-lt \
    --region us-east-1
```

### Step 3: Delete Load Balancer
```bash
# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --names devops-portfolio-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region us-east-1)

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region us-east-1

# Wait for ALB deletion
echo "Waiting for ALB deletion..."
sleep 60
```

### Step 4: Delete Target Group
```bash
TG_ARN=$(aws elbv2 describe-target-groups --names devops-portfolio-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region us-east-1)
aws elbv2 delete-target-group --target-group-arn $TG_ARN --region us-east-1
```

### Step 5: Delete RDS Instance
```bash
# Delete without final snapshot
aws rds delete-db-instance \
    --db-instance-identifier devops-portfolio-db \
    --skip-final-snapshot \
    --region us-east-1

# Wait for deletion (can take 5-10 minutes)
echo "Waiting for RDS deletion... (this takes several minutes)"
aws rds wait db-instance-deleted --db-instance-identifier devops-portfolio-db --region us-east-1
```

### Step 6: Delete DB Subnet Group
```bash
aws rds delete-db-subnet-group \
    --db-subnet-group-name devops-portfolio-subnet-group \
    --region us-east-1
```

### Step 7: Delete Security Groups
```bash
# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=devops-portfolio-vpc" --query 'Vpcs[0].VpcId' --output text --region us-east-1)

# Delete security groups (not the default one)
for sg in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text --region us-east-1); do
    aws ec2 delete-security-group --group-id $sg --region us-east-1
done
```

### Step 8: Delete Subnets
```bash
for subnet in $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text --region us-east-1); do
    aws ec2 delete-subnet --subnet-id $subnet --region us-east-1
done
```

### Step 9: Delete Internet Gateway
```bash
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text --region us-east-1)
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region us-east-1
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region us-east-1
```

### Step 10: Delete Route Tables
```bash
# Delete non-main route tables
for rt in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text --region us-east-1); do
    aws ec2 delete-route-table --route-table-id $rt --region us-east-1
done
```

### Step 11: Delete VPC
```bash
aws ec2 delete-vpc --vpc-id $VPC_ID --region us-east-1
```

### Step 12: Delete CloudWatch Resources
```bash
# Delete dashboard
aws cloudwatch delete-dashboards --dashboard-names devops-portfolio-dashboard --region us-east-1

# Delete alarms
aws cloudwatch delete-alarms --alarm-names devops-portfolio-high-cpu devops-portfolio-unhealthy-targets --region us-east-1
```

## Verify Cleanup

Check that all resources are deleted:

```bash
# Should return empty or "None"
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=devops-portfolio-vpc" --query 'Vpcs[].VpcId' --output text --region us-east-1

aws rds describe-db-instances --db-instance-identifier devops-portfolio-db --region us-east-1 2>&1 | grep -q "DBInstanceNotFound" && echo "RDS deleted"

aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names devops-portfolio-asg --query 'AutoScalingGroups[].AutoScalingGroupName' --output text --region us-east-1
```

## Cost After Cleanup

After cleanup, you should have **$0** ongoing charges from this project.

Check your AWS Billing console to confirm: https://console.aws.amazon.com/billing/
