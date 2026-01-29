#!/bin/bash

# Load IDs
source setup_network_ids.env 2>/dev/null || { echo "Error: Run 01-network.sh first"; exit 1; }
source setup_security_ids.env 2>/dev/null || { echo "Error: Run 02-security.sh first"; exit 1; }
source setup_database_ids.env 2>/dev/null || { echo "Error: Run 03-database.sh first"; exit 1; }

PROJECT_NAME="devops-portfolio"

# Get RDS Endpoint (wait until available)
echo "Getting RDS Endpoint (RDS must be 'available' state)..."
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $PROJECT_NAME-db --query 'DBInstances[0].Endpoint.Address' --output text --region $REGION)

if [ "$RDS_ENDPOINT" == "None" ] || [ -z "$RDS_ENDPOINT" ]; then
    echo "RDS not ready yet. Wait for DB to be 'available' and re-run."
    exit 1
fi
echo "RDS Endpoint: $RDS_ENDPOINT"

# Get latest Amazon Linux 2023 AMI
echo "Getting latest Amazon Linux 2023 AMI..."
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023*-kernel-*-x86_64" "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text --region $REGION)
echo "AMI ID: $AMI_ID"

# Create Target Group
echo "Creating Target Group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name $PROJECT_NAME-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --health-check-protocol HTTP \
    --health-check-path "/" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 5 \
    --target-type instance \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text --region $REGION)
echo "Target Group ARN: $TG_ARN"

# Create Application Load Balancer
echo "Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name $PROJECT_NAME-alb \
    --subnets $PUB_SUB_1 $PUB_SUB_2 \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text --region $REGION)

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text --region $REGION)
echo "ALB ARN: $ALB_ARN"
echo "ALB DNS: $ALB_DNS"

# Create Listener
echo "Creating HTTP Listener..."
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN \
    --region $REGION

# Create User Data Script with RDS endpoint
USER_DATA=$(cat << EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -x
yum update -y
yum install -y httpd php php-mysqlnd php-curl
systemctl start httpd
systemctl enable httpd

cat > /etc/httpd/conf.d/env.conf << 'ENVEOF'
SetEnv DB_HOST ${RDS_ENDPOINT}
SetEnv DB_NAME ${DB_NAME}
SetEnv DB_USER ${DB_USER}
SetEnv DB_PASS ${DB_PASS}
ENVEOF

cat > /var/www/html/index.php << 'PHPEOF'
<?php
\$db_host = getenv('DB_HOST') ?: getenv('REDIRECT_DB_HOST');
\$db_name = getenv('DB_NAME') ?: getenv('REDIRECT_DB_NAME') ?: 'devopsdb';
\$db_user = getenv('DB_USER') ?: getenv('REDIRECT_DB_USER') ?: 'admin';
\$db_pass = getenv('DB_PASS') ?: getenv('REDIRECT_DB_PASS') ?: '';
function getInstanceMetadata(\$path) {
    \$ch = curl_init(); curl_setopt(\$ch, CURLOPT_URL, "http://169.254.169.254/latest/api/token");
    curl_setopt(\$ch, CURLOPT_RETURNTRANSFER, true); curl_setopt(\$ch, CURLOPT_HTTPHEADER, ['X-aws-ec2-metadata-token-ttl-seconds: 21600']);
    curl_setopt(\$ch, CURLOPT_CUSTOMREQUEST, 'PUT'); curl_setopt(\$ch, CURLOPT_TIMEOUT, 2); \$token = curl_exec(\$ch); curl_close(\$ch);
    \$ch = curl_init(); curl_setopt(\$ch, CURLOPT_URL, "http://169.254.169.254/latest/meta-data/" . \$path);
    curl_setopt(\$ch, CURLOPT_RETURNTRANSFER, true); curl_setopt(\$ch, CURLOPT_HTTPHEADER, ["X-aws-ec2-metadata-token: \$token"]);
    curl_setopt(\$ch, CURLOPT_TIMEOUT, 2); \$result = curl_exec(\$ch); curl_close(\$ch); return \$result ?: 'N/A';
}
\$instance_id = getInstanceMetadata('instance-id'); \$az = getInstanceMetadata('placement/availability-zone');
\$private_ip = getInstanceMetadata('local-ipv4'); \$instance_type = getInstanceMetadata('instance-type');
\$db_status = "Disconnected"; \$visit_count = 0; \$db_error = "";
try {
    \$pdo = new PDO("mysql:host=\$db_host;dbname=\$db_name", \$db_user, \$db_pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 5]);
    \$db_status = "Connected";
    \$pdo->exec("CREATE TABLE IF NOT EXISTS visits (id INT AUTO_INCREMENT PRIMARY KEY, instance_id VARCHAR(50), visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ip_address VARCHAR(50))");
    \$visitor_ip = \$_SERVER['HTTP_X_FORWARDED_FOR'] ?? \$_SERVER['REMOTE_ADDR'] ?? 'unknown';
    \$stmt = \$pdo->prepare("INSERT INTO visits (instance_id, ip_address) VALUES (?, ?)"); \$stmt->execute([\$instance_id, \$visitor_ip]);
    \$result = \$pdo->query("SELECT COUNT(*) as count FROM visits"); \$visit_count = \$result->fetch(PDO::FETCH_ASSOC)['count'];
} catch (PDOException \$e) { \$db_status = "Error"; \$db_error = \$e->getMessage(); }
\$current_time = date('Y-m-d H:i:s T');
?><!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>DevOps Portfolio</title><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet"><style>:root{--primary:#6366f1;--success:#10b981;--warning:#f59e0b;--error:#ef4444;--bg-card:rgba(30,41,59,0.8);--text:#f1f5f9;--text-muted:#94a3b8}*{margin:0;padding:0;box-sizing:border-box}body{font-family:'Inter',sans-serif;background:linear-gradient(135deg,#0f172a,#1e293b,#0f172a);min-height:100vh;color:var(--text)}.bg-animation{position:fixed;top:0;left:0;width:100%;height:100%;z-index:-1;background:radial-gradient(circle at 20% 80%,rgba(99,102,241,0.15),transparent 50%),radial-gradient(circle at 80% 20%,rgba(16,185,129,0.1),transparent 50%)}.container{max-width:1200px;margin:0 auto;padding:2rem}header{text-align:center;padding:3rem 0}h1{font-size:2.5rem;font-weight:700;background:linear-gradient(135deg,var(--primary),var(--success));-webkit-background-clip:text;-webkit-text-fill-color:transparent;margin-bottom:.5rem}.subtitle{color:var(--text-muted);font-size:1.1rem}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(350px,1fr));gap:1.5rem;margin-top:2rem}.card{background:var(--bg-card);backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,0.1);border-radius:16px;padding:1.5rem;transition:transform .3s,box-shadow .3s}.card:hover{transform:translateY(-5px);box-shadow:0 20px 40px rgba(0,0,0,0.3)}.card-header{display:flex;align-items:center;gap:.75rem;margin-bottom:1.25rem;padding-bottom:1rem;border-bottom:1px solid rgba(255,255,255,0.1)}.card-icon{width:40px;height:40px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:1.25rem}.icon-instance{background:linear-gradient(135deg,var(--primary),#4f46e5)}.icon-db{background:linear-gradient(135deg,var(--success),#059669)}.icon-stats{background:linear-gradient(135deg,var(--warning),#d97706)}.card-title{font-size:1.1rem;font-weight:600}.info-row{display:flex;justify-content:space-between;padding:.75rem 0;border-bottom:1px solid rgba(255,255,255,0.05)}.info-row:last-child{border-bottom:none}.info-label{color:var(--text-muted);font-size:.9rem}.info-value{font-weight:500;font-family:'Courier New',monospace}.status{display:inline-flex;align-items:center;gap:.5rem;padding:.25rem .75rem;border-radius:20px;font-size:.85rem;font-weight:500}.status-connected{background:rgba(16,185,129,0.2);color:var(--success)}.status-error{background:rgba(239,68,68,0.2);color:var(--error)}.status-dot{width:8px;height:8px;border-radius:50%;animation:pulse 2s infinite}.status-connected .status-dot{background:var(--success)}.status-error .status-dot{background:var(--error)}@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}.visit-counter{text-align:center;padding:2rem}.visit-number{font-size:4rem;font-weight:700;background:linear-gradient(135deg,var(--warning),#f97316);-webkit-background-clip:text;-webkit-text-fill-color:transparent}.visit-label{color:var(--text-muted);margin-top:.5rem}.architecture-badge{display:inline-flex;align-items:center;gap:.5rem;background:rgba(99,102,241,0.1);border:1px solid rgba(99,102,241,0.3);padding:.5rem 1rem;border-radius:8px;margin:.25rem;font-size:.85rem}.badges-container{display:flex;flex-wrap:wrap;justify-content:center;gap:.5rem;margin-top:2rem}footer{text-align:center;padding:2rem;color:var(--text-muted);font-size:.9rem}.refresh-btn{background:linear-gradient(135deg,var(--primary),#4f46e5);color:#fff;border:none;padding:.75rem 1.5rem;border-radius:8px;font-size:1rem;font-weight:500;cursor:pointer;transition:transform .2s;margin-top:1rem}.refresh-btn:hover{transform:scale(1.05)}.error-message{background:rgba(239,68,68,0.1);border:1px solid rgba(239,68,68,0.3);border-radius:8px;padding:1rem;margin-top:1rem;font-size:.85rem;color:var(--error)}</style></head><body><div class="bg-animation"></div><div class="container"><header><h1>🚀 Auto-Scaling Web Application</h1><p class="subtitle">DevOps Portfolio Project - AWS Infrastructure Demo</p><div class="badges-container"><span class="architecture-badge">☁️ EC2</span><span class="architecture-badge">⚖️ ALB</span><span class="architecture-badge">📈 Auto Scaling</span><span class="architecture-badge">🗄️ RDS MySQL</span><span class="architecture-badge">📊 CloudWatch</span></div></header><div class="grid"><div class="card"><div class="card-header"><div class="card-icon icon-instance">🖥️</div><h2 class="card-title">Instance Information</h2></div><div class="info-row"><span class="info-label">Instance ID</span><span class="info-value"><?= htmlspecialchars(\$instance_id) ?></span></div><div class="info-row"><span class="info-label">Availability Zone</span><span class="info-value"><?= htmlspecialchars(\$az) ?></span></div><div class="info-row"><span class="info-label">Private IP</span><span class="info-value"><?= htmlspecialchars(\$private_ip) ?></span></div><div class="info-row"><span class="info-label">Instance Type</span><span class="info-value"><?= htmlspecialchars(\$instance_type) ?></span></div><div class="info-row"><span class="info-label">Timestamp</span><span class="info-value"><?= \$current_time ?></span></div></div><div class="card"><div class="card-header"><div class="card-icon icon-db">🗄️</div><h2 class="card-title">Database Connection</h2></div><div class="info-row"><span class="info-label">Status</span><span class="status <?= \$db_status === 'Connected' ? 'status-connected' : 'status-error' ?>"><span class="status-dot"></span><?= \$db_status ?></span></div><div class="info-row"><span class="info-label">Engine</span><span class="info-value">MySQL (RDS)</span></div><div class="info-row"><span class="info-label">Database</span><span class="info-value"><?= htmlspecialchars(\$db_name) ?></span></div><div class="info-row"><span class="info-label">Host</span><span class="info-value"><?= htmlspecialchars(substr(\$db_host, 0, 30)) ?>...</span></div><?php if (\$db_error): ?><div class="error-message">⚠️ <?= htmlspecialchars(\$db_error) ?></div><?php endif; ?></div><div class="card"><div class="card-header"><div class="card-icon icon-stats">📊</div><h2 class="card-title">Visit Statistics</h2></div><div class="visit-counter"><div class="visit-number"><?= number_format(\$visit_count) ?></div><div class="visit-label">Total Page Visits</div></div><button class="refresh-btn" onclick="location.reload()">🔄 Refresh Page</button></div></div><footer><p>Built with ❤️ for DevOps Portfolio | High Availability</p><p style="margin-top:.5rem">Refresh to see load balancing across instances</p></footer></div></body></html>
PHPEOF
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
systemctl restart httpd
EOF
)

USER_DATA_BASE64=$(echo "$USER_DATA" | base64 -w 0)

# Create Launch Template
echo "Creating Launch Template..."
LT_ID=$(aws ec2 create-launch-template \
    --launch-template-name $PROJECT_NAME-lt \
    --version-description "v1" \
    --launch-template-data "{
        \"ImageId\": \"$AMI_ID\",
        \"InstanceType\": \"t2.micro\",
        \"SecurityGroupIds\": [\"$WEB_SG_ID\"],
        \"UserData\": \"$USER_DATA_BASE64\",
        \"TagSpecifications\": [{
            \"ResourceType\": \"instance\",
            \"Tags\": [{\"Key\": \"Name\", \"Value\": \"$PROJECT_NAME-web\"}]
        }]
    }" \
    --query 'LaunchTemplate.LaunchTemplateId' \
    --output text --region $REGION)
echo "Launch Template ID: $LT_ID"

# Create Auto Scaling Group
echo "Creating Auto Scaling Group..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name $PROJECT_NAME-asg \
    --launch-template LaunchTemplateId=$LT_ID,Version=1 \
    --min-size 2 \
    --max-size 6 \
    --desired-capacity 2 \
    --vpc-zone-identifier "$PUB_SUB_1,$PUB_SUB_2" \
    --target-group-arns $TG_ARN \
    --health-check-type ELB \
    --health-check-grace-period 300 \
    --default-instance-warmup 300 \
    --tags Key=Name,Value=$PROJECT_NAME-asg,PropagateAtLaunch=true \
    --region $REGION

echo "Creating Target Tracking Scaling Policy (50% CPU)..."
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name $PROJECT_NAME-asg \
    --policy-name $PROJECT_NAME-cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration '{
        "TargetValue": 50.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ASGAverageCPUUtilization"
        },
        "ScaleOutCooldown": 300,
        "ScaleInCooldown": 300
    }' \
    --region $REGION

# Save outputs
echo "ALB_ARN=$ALB_ARN" > setup_scaling_ids.env
echo "ALB_DNS=$ALB_DNS" >> setup_scaling_ids.env
echo "TG_ARN=$TG_ARN" >> setup_scaling_ids.env
echo "LT_ID=$LT_ID" >> setup_scaling_ids.env
echo "RDS_ENDPOINT=$RDS_ENDPOINT" >> setup_scaling_ids.env

echo ""
echo "========================================"
echo "Phase 5 Complete: ALB and Auto Scaling Configured"
echo "========================================"
echo ""
echo "ACCESS YOUR APPLICATION AT:"
echo "http://$ALB_DNS"
echo ""
echo "Wait 3-5 minutes for instances to pass health checks."
