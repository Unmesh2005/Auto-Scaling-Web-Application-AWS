#!/bin/bash
# Alternative load test using Apache Bench (ab)
# Install: yum install httpd-tools (Amazon Linux) or apt install apache2-utils (Ubuntu)

if [ -z "$1" ]; then
    echo "Usage: ./load-test-ab.sh <ALB_DNS_NAME>"
    echo "Example: ./load-test-ab.sh devops-portfolio-alb-123.us-east-1.elb.amazonaws.com"
    exit 1
fi

ALB_DNS=$1
URL="http://$ALB_DNS/"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🚀 AUTO-SCALING LOAD TESTER (Apache Bench)                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Target: $ALB_DNS"
echo "║  Total Requests: 100,000                                     ║"
echo "║  Concurrent: 100                                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if ab is installed
if ! command -v ab &> /dev/null; then
    echo "Apache Bench (ab) not found. Install with:"
    echo "  Amazon Linux: yum install httpd-tools"
    echo "  Ubuntu/Debian: apt install apache2-utils"
    echo "  macOS: brew install httpd"
    exit 1
fi

echo "Starting load test... This will take several minutes."
echo "Monitor your CloudWatch dashboard and ASG in another terminal."
echo ""

# Run Apache Bench: 100,000 requests, 100 concurrent
ab -n 100000 -c 100 -k "$URL"

echo ""
echo "Load test complete!"
echo ""
echo "Check ASG status:"
echo "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names devops-portfolio-asg --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize]'"
