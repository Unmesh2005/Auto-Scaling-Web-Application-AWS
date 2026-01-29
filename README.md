# 🚀 Auto-Scaling Web Application on AWS

A production-ready, highly available web application demonstrating DevOps best practices with AWS services.

![AWS](https://img.shields.io/badge/AWS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)

## 📋 Overview

This project implements a **highly available, auto-scaling web application** on AWS using:

- **VPC** with public/private subnets across 2 Availability Zones
- **Application Load Balancer** for traffic distribution
- **Auto Scaling Group** (2-6 instances) with CPU-based scaling
- **RDS MySQL** database in private subnets
- **CloudWatch** monitoring with custom dashboards and alarms

## 🏗️ Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │                 INTERNET                    │
                    └────────────────────┬────────────────────────┘
                                         │
                    ┌────────────────────▼────────────────────────┐
                    │           Internet Gateway (IGW)            │
                    └────────────────────┬────────────────────────┘
                                         │
        ┌────────────────────────────────┴────────────────────────────────┐
        │                            VPC (10.0.0.0/16)                    │
        │  ┌──────────────────────────────────────────────────────────┐   │
        │  │                  APPLICATION LOAD BALANCER               │   │
        │  └─────────────────┬────────────────────┬───────────────────┘   │
        │                    │                    │                       │
        │  ┌─────────────────▼────────┐  ┌───────▼─────────────────┐      │
        │  │   PUBLIC SUBNET 1        │  │   PUBLIC SUBNET 2       │      │
        │  │   (10.0.1.0/24)          │  │   (10.0.2.0/24)         │      │
        │  │   AZ: us-east-1a         │  │   AZ: us-east-1b        │      │
        │  │  ┌─────────────────┐     │  │  ┌─────────────────┐    │      │
        │  │  │   EC2 (ASG)     │     │  │  │   EC2 (ASG)     │    │      │
        │  │  │   t2.micro      │     │  │  │   t2.micro      │    │      │
        │  │  └─────────────────┘     │  │  └─────────────────┘    │      │
        │  └─────────────────┬────────┘  └───────┬─────────────────┘      │
        │                    │                    │                       │
        │  ┌─────────────────▼────────┐  ┌───────▼─────────────────┐      │
        │  │   PRIVATE SUBNET 1       │  │   PRIVATE SUBNET 2      │      │
        │  │   (10.0.11.0/24)         │  │   (10.0.12.0/24)        │      │
        │  │   AZ: us-east-1a         │  │   AZ: us-east-1b        │      │
        │  │  ┌─────────────────────────────────────────────┐     │      │
        │  │  │            RDS MySQL (db.t3.micro)          │     │      │
        │  │  │              Single-AZ (Free Tier)          │     │      │
        │  │  └─────────────────────────────────────────────┘     │      │
        │  └──────────────────────────────────────────────────────┘      │
        └─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate credentials
- Bash shell (Git Bash on Windows, or Linux/macOS)
- Python 3.x (for load testing)

### Deployment Steps

```bash
# Navigate to infrastructure folder
cd infrastructure

# Phase 1: Create VPC and Network
./01-network.sh

# Phase 2: Create Security Groups
./02-security.sh

# Phase 3: Create RDS Database (wait 10-15 min for availability)
./03-database.sh

# Phase 4: Create ALB and Auto Scaling (run after RDS is available)
./04-scaling.sh

# Phase 5: Set up CloudWatch Monitoring
cd ../monitoring
./05-cloudwatch.sh
```

### Access Your Application
After deployment, access via the ALB DNS name printed in the output:
```
http://devops-portfolio-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com
```

## 🧪 Testing Auto-Scaling

### Using Python Script
```bash
cd tests
python load-test.py <ALB_DNS_NAME> 300 50
```

### Using Apache Bench
```bash
cd tests
./load-test-ab.sh <ALB_DNS_NAME>
```

### Verify Scaling
```bash
# Check ASG status
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names devops-portfolio-asg \
    --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize]'
```

## 📊 Monitoring

Access CloudWatch Dashboard:
```
https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=devops-portfolio-dashboard
```

### Metrics Tracked
- Auto Scaling Group instance count
- EC2 CPU utilization
- ALB request count and response time
- Healthy/unhealthy target hosts
- RDS CPU and connections

## 🔒 Security

| Security Group | Inbound Rules |
|---------------|---------------|
| ALB SG | HTTP (80), HTTPS (443) from 0.0.0.0/0 |
| Web Server SG | HTTP (80) from ALB SG, SSH (22) from your IP |
| RDS SG | MySQL (3306) from Web Server SG only |

## 💰 Cost Optimization

This project uses **Free Tier eligible** resources:
- EC2: t2.micro instances
- RDS: db.t3.micro, single-AZ, no backups
- No NAT Gateway (saves ~$32/month)

**⚠️ Important**: Remember to clean up resources after testing!

## 🧹 Cleanup

```bash
cd infrastructure
./cleanup.sh
```

Or manually delete in this order:
1. Auto Scaling Group
2. Launch Template
3. Load Balancer & Target Group
4. RDS Instance & Subnet Group
5. Security Groups
6. Subnets, Route Tables, IGW
7. VPC

## 📁 Project Structure

```
Auto-Scaling Web Application/
├── infrastructure/
│   ├── 01-network.sh       # VPC, Subnets, IGW
│   ├── 02-security.sh      # Security Groups
│   ├── 03-database.sh      # RDS MySQL
│   ├── 04-scaling.sh       # ALB, ASG, Launch Template
│   └── cleanup.sh          # Resource cleanup
├── app/
│   ├── index.php           # PHP web application
│   └── user-data.sh        # EC2 bootstrap script
├── monitoring/
│   └── 05-cloudwatch.sh    # Dashboard & Alarms
├── tests/
│   ├── load-test.py        # Python load tester
│   └── load-test-ab.sh     # Apache Bench script
└── docs/
    ├── ARCHITECTURE.md
    ├── INTERVIEW_POINTS.md
    └── CLEANUP.md
```

## 🎯 Skills Demonstrated

- Infrastructure as Code (AWS CLI)
- High Availability architecture design
- Auto-scaling configuration
- Load balancing
- Database management (RDS)
- CloudWatch monitoring
- Security best practices
- Cost optimization

## 📝 License

MIT License - feel free to use for your portfolio!

---

**Built with ❤️ for DevOps Portfolio**
