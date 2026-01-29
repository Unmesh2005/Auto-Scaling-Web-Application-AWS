<?php
// =========================================================
// DevOps Portfolio - Auto-Scaling Web Application
// Demonstrates: EC2, RDS, ALB, Auto Scaling, CloudWatch
// =========================================================

// Database Configuration (injected via user-data)
$db_host = getenv('DB_HOST') ?: 'YOUR_RDS_ENDPOINT';
$db_name = getenv('DB_NAME') ?: 'devopsdb';
$db_user = getenv('DB_USER') ?: 'admin';
$db_pass = getenv('DB_PASS') ?: 'Password123!';

// Get Instance Metadata (IMDSv2)
function getInstanceMetadata($path) {
    // Get token first (IMDSv2)
    $token_url = "http://169.254.169.254/latest/api/token";
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $token_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['X-aws-ec2-metadata-token-ttl-seconds: 21600']);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
    curl_setopt($ch, CURLOPT_TIMEOUT, 2);
    $token = curl_exec($ch);
    curl_close($ch);
    
    // Get metadata with token
    $metadata_url = "http://169.254.169.254/latest/meta-data/" . $path;
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $metadata_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["X-aws-ec2-metadata-token: $token"]);
    curl_setopt($ch, CURLOPT_TIMEOUT, 2);
    $result = curl_exec($ch);
    curl_close($ch);
    
    return $result ?: 'N/A';
}

$instance_id = getInstanceMetadata('instance-id');
$availability_zone = getInstanceMetadata('placement/availability-zone');
$private_ip = getInstanceMetadata('local-ipv4');
$instance_type = getInstanceMetadata('instance-type');

// Database Connection
$db_status = "Disconnected";
$visit_count = 0;
$db_error = "";

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 5
    ]);
    $db_status = "Connected";
    
    // Create visits table if not exists
    $pdo->exec("CREATE TABLE IF NOT EXISTS visits (
        id INT AUTO_INCREMENT PRIMARY KEY,
        instance_id VARCHAR(50),
        visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        ip_address VARCHAR(50)
    )");
    
    // Record this visit
    $visitor_ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $stmt = $pdo->prepare("INSERT INTO visits (instance_id, ip_address) VALUES (?, ?)");
    $stmt->execute([$instance_id, $visitor_ip]);
    
    // Get total visits
    $result = $pdo->query("SELECT COUNT(*) as count FROM visits");
    $visit_count = $result->fetch(PDO::FETCH_ASSOC)['count'];
    
} catch (PDOException $e) {
    $db_status = "Error";
    $db_error = $e->getMessage();
}

$current_time = date('Y-m-d H:i:s T');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Portfolio - Auto-Scaling Demo</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #6366f1;
            --primary-dark: #4f46e5;
            --success: #10b981;
            --warning: #f59e0b;
            --error: #ef4444;
            --bg-dark: #0f172a;
            --bg-card: rgba(30, 41, 59, 0.8);
            --text: #f1f5f9;
            --text-muted: #94a3b8;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Inter', sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #0f172a 100%);
            min-height: 100vh;
            color: var(--text);
            overflow-x: hidden;
        }
        
        .bg-animation {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: -1;
            background: 
                radial-gradient(circle at 20% 80%, rgba(99, 102, 241, 0.15) 0%, transparent 50%),
                radial-gradient(circle at 80% 20%, rgba(16, 185, 129, 0.1) 0%, transparent 50%),
                radial-gradient(circle at 50% 50%, rgba(245, 158, 11, 0.05) 0%, transparent 50%);
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        header {
            text-align: center;
            padding: 3rem 0;
        }
        
        h1 {
            font-size: 2.5rem;
            font-weight: 700;
            background: linear-gradient(135deg, var(--primary) 0%, var(--success) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 0.5rem;
        }
        
        .subtitle {
            color: var(--text-muted);
            font-size: 1.1rem;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 1.5rem;
            margin-top: 2rem;
        }
        
        .card {
            background: var(--bg-card);
            backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 16px;
            padding: 1.5rem;
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
        }
        
        .card-header {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            margin-bottom: 1.25rem;
            padding-bottom: 1rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .card-icon {
            width: 40px;
            height: 40px;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.25rem;
        }
        
        .icon-instance { background: linear-gradient(135deg, var(--primary), var(--primary-dark)); }
        .icon-db { background: linear-gradient(135deg, var(--success), #059669); }
        .icon-stats { background: linear-gradient(135deg, var(--warning), #d97706); }
        
        .card-title {
            font-size: 1.1rem;
            font-weight: 600;
        }
        
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 0.75rem 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        }
        
        .info-row:last-child {
            border-bottom: none;
        }
        
        .info-label {
            color: var(--text-muted);
            font-size: 0.9rem;
        }
        
        .info-value {
            font-weight: 500;
            font-family: 'Courier New', monospace;
            color: var(--text);
        }
        
        .status {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 500;
        }
        
        .status-connected {
            background: rgba(16, 185, 129, 0.2);
            color: var(--success);
        }
        
        .status-error {
            background: rgba(239, 68, 68, 0.2);
            color: var(--error);
        }
        
        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        
        .status-connected .status-dot { background: var(--success); }
        .status-error .status-dot { background: var(--error); }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .visit-counter {
            text-align: center;
            padding: 2rem;
        }
        
        .visit-number {
            font-size: 4rem;
            font-weight: 700;
            background: linear-gradient(135deg, var(--warning), #f97316);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .visit-label {
            color: var(--text-muted);
            font-size: 1rem;
            margin-top: 0.5rem;
        }
        
        .architecture-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: rgba(99, 102, 241, 0.1);
            border: 1px solid rgba(99, 102, 241, 0.3);
            padding: 0.5rem 1rem;
            border-radius: 8px;
            margin: 0.25rem;
            font-size: 0.85rem;
        }
        
        .badges-container {
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            gap: 0.5rem;
            margin-top: 2rem;
        }
        
        footer {
            text-align: center;
            padding: 2rem;
            color: var(--text-muted);
            font-size: 0.9rem;
        }
        
        .refresh-btn {
            background: linear-gradient(135deg, var(--primary), var(--primary-dark));
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            font-size: 1rem;
            font-weight: 500;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
            margin-top: 1rem;
        }
        
        .refresh-btn:hover {
            transform: scale(1.05);
            box-shadow: 0 10px 30px rgba(99, 102, 241, 0.3);
        }
        
        .error-message {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(239, 68, 68, 0.3);
            border-radius: 8px;
            padding: 1rem;
            margin-top: 1rem;
            font-size: 0.85rem;
            color: var(--error);
        }
    </style>
</head>
<body>
    <div class="bg-animation"></div>
    
    <div class="container">
        <header>
            <h1>🚀 Auto-Scaling Web Application</h1>
            <p class="subtitle">DevOps Portfolio Project - AWS Infrastructure Demo</p>
            
            <div class="badges-container">
                <span class="architecture-badge">☁️ EC2</span>
                <span class="architecture-badge">⚖️ ALB</span>
                <span class="architecture-badge">📈 Auto Scaling</span>
                <span class="architecture-badge">🗄️ RDS MySQL</span>
                <span class="architecture-badge">📊 CloudWatch</span>
            </div>
        </header>
        
        <div class="grid">
            <!-- Instance Information Card -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon icon-instance">🖥️</div>
                    <h2 class="card-title">Instance Information</h2>
                </div>
                <div class="info-row">
                    <span class="info-label">Instance ID</span>
                    <span class="info-value"><?= htmlspecialchars($instance_id) ?></span>
                </div>
                <div class="info-row">
                    <span class="info-label">Availability Zone</span>
                    <span class="info-value"><?= htmlspecialchars($availability_zone) ?></span>
                </div>
                <div class="info-row">
                    <span class="info-label">Private IP</span>
                    <span class="info-value"><?= htmlspecialchars($private_ip) ?></span>
                </div>
                <div class="info-row">
                    <span class="info-label">Instance Type</span>
                    <span class="info-value"><?= htmlspecialchars($instance_type) ?></span>
                </div>
                <div class="info-row">
                    <span class="info-label">Timestamp</span>
                    <span class="info-value"><?= $current_time ?></span>
                </div>
            </div>
            
            <!-- Database Connection Card -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon icon-db">🗄️</div>
                    <h2 class="card-title">Database Connection</h2>
                </div>
                <div class="info-row">
                    <span class="info-label">Status</span>
                    <span class="status <?= $db_status === 'Connected' ? 'status-connected' : 'status-error' ?>">
                        <span class="status-dot"></span>
                        <?= $db_status ?>
                    </span>
                </div>
                <div class="info-row">
                    <span class="info-label">Engine</span>
                    <span class="info-value">MySQL (RDS)</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Database</span>
                    <span class="info-value"><?= htmlspecialchars($db_name) ?></span>
                </div>
                <div class="info-row">
                    <span class="info-label">Host</span>
                    <span class="info-value"><?= htmlspecialchars(substr($db_host, 0, 30)) ?>...</span>
                </div>
                <?php if ($db_error): ?>
                <div class="error-message">
                    ⚠️ <?= htmlspecialchars($db_error) ?>
                </div>
                <?php endif; ?>
            </div>
            
            <!-- Visit Statistics Card -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon icon-stats">📊</div>
                    <h2 class="card-title">Visit Statistics</h2>
                </div>
                <div class="visit-counter">
                    <div class="visit-number"><?= number_format($visit_count) ?></div>
                    <div class="visit-label">Total Page Visits</div>
                </div>
                <button class="refresh-btn" onclick="location.reload()">
                    🔄 Refresh Page
                </button>
            </div>
        </div>
        
        <footer>
            <p>Built with ❤️ for DevOps Portfolio | High Availability across <?= htmlspecialchars(substr($availability_zone, 0, -1)) ?></p>
            <p style="margin-top: 0.5rem;">Refresh the page multiple times to see load balancing across instances</p>
        </footer>
    </div>
    
    <script>
        // Auto-refresh every 30 seconds to show load balancing
        // setTimeout(() => location.reload(), 30000);
    </script>
</body>
</html>
