# 🎯 Interview Talking Points

Use these points to discuss your project in interviews and portfolio presentations.

## Project Overview (30-second pitch)

> "I built a highly available, auto-scaling web application on AWS that demonstrates production-ready infrastructure. It uses an Application Load Balancer to distribute traffic across EC2 instances in an Auto Scaling Group, with a MySQL database on RDS. The application automatically scales from 2 to 6 instances based on CPU utilization, and I set up CloudWatch monitoring with custom dashboards and alarms."

## Key Technical Decisions

### 1. Why Auto Scaling?
- **Cost Optimization**: Scale down during low traffic, scale up during peaks
- **High Availability**: Automatically replace failed instances
- **Performance**: Maintain response times under load

### 2. Why ALB over NLB?
- Application-level routing (HTTP/HTTPS)
- Path-based routing capability
- Built-in health checks at application layer
- Better integration with Auto Scaling Groups

### 3. Why RDS over self-managed MySQL?
- Managed backups and patching
- Easy scaling (vertical and read replicas)
- Built-in monitoring and metrics
- Free Tier eligibility

### 4. Why public subnets for EC2?
- Cost savings: No NAT Gateway needed (~$32/month)
- Direct internet access for package updates
- Security Groups still protect the instances
- Trade-off: In production, might use private subnets + NAT

## Challenges & Solutions

### Challenge 1: IMDSv2 for Instance Metadata
- **Problem**: AWS recommends IMDSv2 for security
- **Solution**: Implemented token-based metadata retrieval in PHP
- **Learning**: Modern security practices vs. legacy IMDSv1

### Challenge 2: Database Connection in User Data
- **Problem**: RDS endpoint unknown until instance creates
- **Solution**: Script waits for RDS availability, injects endpoint into user data
- **Learning**: Infrastructure dependencies and ordering

### Challenge 3: Health Check Timing
- **Problem**: Instances marked unhealthy before app fully started
- **Solution**: 300-second grace period matches warmup time
- **Learning**: Importance of tuning health check parameters

## Metrics & Results

- **Availability**: Multi-AZ deployment across 2 availability zones
- **Scalability**: 2-6 instances based on 50% CPU target
- **Response Time**: Sub-second with load balancing
- **Cost**: Free Tier eligible, ~$45/month without Free Tier

## Questions You Might Get

### "How would you improve this for production?"
1. Enable Multi-AZ for RDS
2. Add HTTPS with ACM certificate
3. Use private subnets + NAT Gateway
4. Implement CI/CD pipeline
5. Add WAF for security
6. Use Secrets Manager for credentials

### "How does auto-scaling work?"
"I configured target tracking scaling with a 50% CPU target. CloudWatch monitors CPU utilization every minute. When the average exceeds the target for the evaluation period, ASG launches new instances. There's a 300-second warmup to prevent premature scaling decisions."

### "What happens if an instance fails?"
"The ALB health checks detect the failure within 30-60 seconds and stops routing traffic. The ASG terminates the unhealthy instance and launches a replacement. The new instance goes through health checks before receiving traffic."

### "How did you test the auto-scaling?"
"I wrote a Python load testing script that generates concurrent HTTP requests. Running 50 workers for 5+ minutes drives CPU above 50%, triggering scale-out. I monitored the CloudWatch dashboard to watch instance count increase from 2 to 4-6."

## Skills Demonstrated

| Skill | How Demonstrated |
|-------|------------------|
| AWS Services | EC2, VPC, ALB, ASG, RDS, CloudWatch |
| Infrastructure as Code | Bash scripts with AWS CLI |
| High Availability | Multi-AZ deployment |
| Auto-scaling | CPU-based target tracking |
| Monitoring | Custom CloudWatch dashboard |
| Security | Security groups, least privilege |
| Cost Optimization | Free Tier resources, no NAT |
| Documentation | README, architecture docs |

## Resume Bullet Points

- Designed and implemented a highly available web application on AWS with auto-scaling (2-6 instances) based on CPU utilization
- Built VPC infrastructure with public/private subnets across multiple availability zones
- Configured Application Load Balancer with health checks and target groups for traffic distribution
- Set up CloudWatch monitoring with custom dashboards tracking CPU, requests, and response times
- Implemented cost-optimized architecture using Free Tier resources while maintaining production-ready design
