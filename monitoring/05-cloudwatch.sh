#!/bin/bash

# Load IDs
source setup_network_ids.env 2>/dev/null || { echo "Error: Run previous scripts first"; exit 1; }
source setup_scaling_ids.env 2>/dev/null || { echo "Error: Run 04-scaling.sh first"; exit 1; }

PROJECT_NAME="devops-portfolio"

echo "Creating CloudWatch Dashboard..."

# Create Dashboard JSON
DASHBOARD_JSON='{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "title": "Auto Scaling Group - Instance Count",
                "metrics": [
                    ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "'$PROJECT_NAME'-asg", {"label": "Desired", "color": "#2ca02c"}],
                    [".", "GroupInServiceInstances", ".", ".", {"label": "In Service", "color": "#1f77b4"}],
                    [".", "GroupMinSize", ".", ".", {"label": "Min", "color": "#ff7f0e"}],
                    [".", "GroupMaxSize", ".", ".", {"label": "Max", "color": "#d62728"}]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "'$REGION'",
                "period": 60,
                "stat": "Average"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "title": "EC2 CPU Utilization (Auto Scaling Target: 50%)",
                "metrics": [
                    ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "'$PROJECT_NAME'-asg", {"label": "CPU %", "color": "#9467bd"}]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "'$REGION'",
                "period": 60,
                "stat": "Average",
                "annotations": {
                    "horizontal": [
                        {"label": "Scaling Target", "value": 50, "color": "#ff7f0e"},
                        {"label": "High CPU Alarm", "value": 70, "color": "#d62728"}
                    ]
                }
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "title": "ALB - Request Count",
                "metrics": [
                    ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "'${ALB_ARN##*/}'", {"label": "Requests", "color": "#17becf"}]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "'$REGION'",
                "period": 60,
                "stat": "Sum"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "title": "ALB - Target Response Time",
                "metrics": [
                    ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "'${ALB_ARN##*/}'", {"label": "Response Time (s)", "color": "#e377c2"}]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "'$REGION'",
                "period": 60,
                "stat": "Average"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 12,
            "width": 12,
            "height": 6,
            "properties": {
                "title": "ALB - Healthy vs Unhealthy Hosts",
                "metrics": [
                    ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "'${TG_ARN##*/}'", "LoadBalancer", "'${ALB_ARN##*/}'", {"label": "Healthy", "color": "#2ca02c"}],
                    [".", "UnHealthyHostCount", ".", ".", ".", ".", {"label": "Unhealthy", "color": "#d62728"}]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "'$REGION'",
                "period": 60,
                "stat": "Average"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 12,
            "width": 12,
            "height": 6,
            "properties": {
                "title": "RDS - CPU & Connections",
                "metrics": [
                    ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "'$PROJECT_NAME'-db", {"label": "CPU %", "color": "#9467bd"}],
                    [".", "DatabaseConnections", ".", ".", {"label": "Connections", "yAxis": "right", "color": "#8c564b"}]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "'$REGION'",
                "period": 60,
                "stat": "Average"
            }
        }
    ]
}'

aws cloudwatch put-dashboard \
    --dashboard-name $PROJECT_NAME-dashboard \
    --dashboard-body "$DASHBOARD_JSON" \
    --region $REGION

echo "Creating CloudWatch Alarms..."

# High CPU Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name $PROJECT_NAME-high-cpu \
    --alarm-description "Alarm when CPU exceeds 70%" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold 70 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=AutoScalingGroupName,Value=$PROJECT_NAME-asg \
    --evaluation-periods 2 \
    --treat-missing-data notBreaching \
    --region $REGION

# Unhealthy Target Alarm
aws cloudwatch put-metric-alarm \
    --alarm-name $PROJECT_NAME-unhealthy-targets \
    --alarm-description "Alarm when there are unhealthy targets" \
    --metric-name UnHealthyHostCount \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 60 \
    --threshold 0 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=TargetGroup,Value=${TG_ARN##*/} Name=LoadBalancer,Value=${ALB_ARN##*/} \
    --evaluation-periods 2 \
    --treat-missing-data notBreaching \
    --region $REGION

echo ""
echo "========================================"
echo "Phase 6 Complete: Monitoring Configured"
echo "========================================"
echo ""
echo "View Dashboard at:"
echo "https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$PROJECT_NAME-dashboard"
