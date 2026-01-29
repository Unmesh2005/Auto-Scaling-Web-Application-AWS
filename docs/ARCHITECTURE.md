# 🏗️ Architecture Documentation

## High-Level Overview

This document describes the architecture of the Auto-Scaling Web Application deployed on AWS.

## Components

### 1. Networking (VPC)

| Component | Configuration |
|-----------|--------------|
| VPC CIDR | 10.0.0.0/16 |
| Public Subnet 1 | 10.0.1.0/24 (us-east-1a) |
| Public Subnet 2 | 10.0.2.0/24 (us-east-1b) |
| Private Subnet 1 | 10.0.11.0/24 (us-east-1a) |
| Private Subnet 2 | 10.0.12.0/24 (us-east-1b) |
| Internet Gateway | Attached to VPC |

### 2. Compute (EC2 + Auto Scaling)

| Setting | Value |
|---------|-------|
| Instance Type | t2.micro |
| AMI | Amazon Linux 2023 |
| Min Instances | 2 |
| Max Instances | 6 |
| Desired Capacity | 2 |
| Scaling Metric | CPU Utilization |
| Target Value | 50% |
| Warmup Period | 300 seconds |

### 3. Load Balancing (ALB)

| Setting | Value |
|---------|-------|
| Type | Application |
| Scheme | Internet-facing |
| Protocol | HTTP (80) |
| Health Check Path | / |
| Health Check Interval | 30 seconds |
| Healthy Threshold | 2 |
| Unhealthy Threshold | 5 |

### 4. Database (RDS)

| Setting | Value |
|---------|-------|
| Engine | MySQL |
| Instance Class | db.t3.micro |
| Storage | 20 GB (GP2) |
| Multi-AZ | No (Free Tier) |
| Publicly Accessible | No |
| Backup Retention | 0 days |

## Data Flow

```
User Request → Internet → IGW → ALB → EC2 (ASG) → RDS MySQL
                                ↓
                         CloudWatch Metrics
```

1. User sends HTTP request to ALB DNS
2. ALB distributes traffic across healthy EC2 instances
3. EC2 instance processes request (PHP)
4. Application queries RDS for visit data
5. Response returned through same path
6. CloudWatch collects metrics throughout

## Security Architecture

```
Internet → [ALB SG: 80,443] → [Web SG: 80 from ALB] → [RDS SG: 3306 from Web]
```

- **Defense in Depth**: Each tier has its own security group
- **Least Privilege**: Only required ports are open
- **Private Database**: RDS is not publicly accessible

## Scaling Behavior

1. **Scale Out** (Add instances):
   - Triggered when average CPU > 50% for 3+ minutes
   - Adds instances up to max (6)
   - 300-second cooldown between scaling actions

2. **Scale In** (Remove instances):
   - Triggered when average CPU < 50%
   - Removes instances down to min (2)
   - 300-second cooldown to prevent flapping

## High Availability

- **Multi-AZ Deployment**: Resources span us-east-1a and us-east-1b
- **Load Balancing**: ALB distributes traffic, fails over automatically
- **Health Checks**: Unhealthy instances are replaced by ASG
- **Database**: Single-AZ for cost (Multi-AZ available for production)

## Cost Considerations

| Resource | Monthly Cost (Estimate) |
|----------|------------------------|
| 2x t2.micro EC2 | Free Tier / ~$17 |
| ALB | ~$16 + data transfer |
| RDS db.t3.micro | Free Tier / ~$12 |
| CloudWatch | Free Tier / minimal |
| **Total** | **Free Tier or ~$45/month** |

**Cost Savings**:
- No NAT Gateway (~$32/month saved)
- RDS Single-AZ (~$12/month saved)
- No dedicated EC2 instances
