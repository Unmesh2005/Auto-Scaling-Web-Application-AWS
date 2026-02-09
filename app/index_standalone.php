<?php
// =========================================================
// DevOps Portfolio - Auto-Scaling Web Application
// STANDALONE VERSION - Works with PostgreSQL (Render) or MySQL
// =========================================================

// Database Configuration - supports Render's DATABASE_URL format
$database_url = getenv('DATABASE_URL');

if ($database_url) {
    // Parse Render's PostgreSQL URL: postgres://user:pass@host:port/dbname
    $db_parts = parse_url($database_url);
    $db_host = $db_parts['host'] ?? 'localhost';
    $db_port = $db_parts['port'] ?? 5432;
    $db_name = ltrim($db_parts['path'] ?? '/devopsdb', '/');
    $db_user = $db_parts['user'] ?? 'postgres';
    $db_pass = $db_parts['pass'] ?? '';
    $db_type = 'pgsql'; // PostgreSQL
} else {
    // Fallback to MySQL for local Docker
    $db_host = getenv('DB_HOST') ?: 'localhost';
    $db_port = 3306;
    $db_name = getenv('DB_NAME') ?: 'devopsdb';
    $db_user = getenv('DB_USER') ?: 'root';
    $db_pass = getenv('DB_PASS') ?: '';
    $db_type = 'mysql';
}

// Demo mode - only if no database extensions available
$demo_mode = !extension_loaded('pdo_pgsql') && !extension_loaded('pdo_mysql');

// Mock Instance Metadata (simulates AWS EC2 for demo)
function getInstanceMetadata($path) {
    $mock_data = [
        'instance-id' => 'demo-' . substr(md5($_SERVER['SERVER_NAME'] ?? 'local'), 0, 8),
        'placement/availability-zone' => 'local-1a',
        'local-ipv4' => $_SERVER['SERVER_ADDR'] ?? '127.0.0.1',
        'instance-type' => 'demo.local'
    ];
    return $mock_data[$path] ?? 'N/A';
}

$instance_id = getInstanceMetadata('instance-id');
$availability_zone = getInstanceMetadata('placement/availability-zone');
$private_ip = getInstanceMetadata('local-ipv4');
$instance_type = getInstanceMetadata('instance-type');

// Database Connection
$db_status = "Disconnected";
$visit_count = 0;
$db_error = "";

if (!$demo_mode) {
    // Retry logic for container startup (waits for DB)
    $max_retries = 5;
    $retry_delay = 2; // seconds
    $attempt = 0;
    $connected = false;

    while ($attempt < $max_retries && !$connected) {
        try {
            // Build DSN based on database type
            if ($db_type === 'pgsql') {
                $dsn = "pgsql:host=$db_host;port=$db_port;dbname=$db_name";
            } else {
                $dsn = "mysql:host=$db_host;port=$db_port;dbname=$db_name";
            }
            
            $pdo = new PDO($dsn, $db_user, $db_pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 5
            ]);
            $connected = true;
            $db_status = "Connected";
        } catch (PDOException $e) {
            $attempt++;
            if ($attempt < $max_retries) {
                sleep($retry_delay);
            } else {
                $db_error = $e->getMessage();
                $demo_mode = true; 
            }
        }
    }
    
    if ($connected) {
        try {
            // Create visits table - PostgreSQL compatible syntax
            if ($db_type === 'pgsql') {
                $pdo->exec("CREATE TABLE IF NOT EXISTS visits (
                    id SERIAL PRIMARY KEY,
                    instance_id VARCHAR(50),
                    visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    ip_address VARCHAR(50)
                )");
            } else {
                $pdo->exec("CREATE TABLE IF NOT EXISTS visits (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    instance_id VARCHAR(50),
                    visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    ip_address VARCHAR(50)
                )");
            }
            
            // Record this visit
            $visitor_ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
            $stmt = $pdo->prepare("INSERT INTO visits (instance_id, ip_address) VALUES (?, ?)");
            $stmt->execute([$instance_id, $visitor_ip]);
            
            // Get total visits
            $result = $pdo->query("SELECT COUNT(*) as count FROM visits");
            $visit_count = $result->fetch(PDO::FETCH_ASSOC)['count'];
        } catch (PDOException $e) {
            $db_status = "Error";
            $db_error = "Query failed: " . $e->getMessage();
        }
    }
}

if ($demo_mode) {
    $db_status = "Demo Mode";
    $visit_count = rand(100, 9999); // Simulated visits
    $db_host = "demo-database";
    $db_error = ""; // Clear error in demo mode - this is expected behavior
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
        
        .demo-banner {
            background: linear-gradient(135deg, rgba(99, 102, 241, 0.2), rgba(16, 185, 129, 0.2));
            border: 1px solid rgba(99, 102, 241, 0.3);
            border-radius: 12px;
            padding: 1rem 1.5rem;
            margin: 1rem auto;
            max-width: 600px;
            text-align: center;
        }
        
        .demo-banner strong {
            color: var(--primary);
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
        
        .status-demo {
            background: rgba(99, 102, 241, 0.2);
            color: var(--primary);
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
        .status-demo .status-dot { background: var(--primary); }
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
        
        @media (max-width: 768px) {
            .grid {
                grid-template-columns: 1fr;
            }
            h1 {
                font-size: 1.8rem;
            }
        }
    </style>
</head>
<body>
    <div class="bg-animation"></div>
    
    <div class="container">
        <header>
            <h1>🚀 Auto-Scaling Web Application</h1>
            <p class="subtitle">DevOps Portfolio Project - AWS Infrastructure Demo</p>
            
            <?php if ($demo_mode): ?>
            <div class="demo-banner">
                🎮 <strong>Demo Mode</strong> - Running without AWS/MySQL. Connect a database for full features!
            </div>
            <?php endif; ?>
            
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
                    <?php if ($db_status === 'Connected'): ?>
                    <span class="status status-connected">
                        <span class="status-dot"></span>
                        <?= $db_status ?>
                    </span>
                    <?php elseif ($db_status === 'Demo Mode'): ?>
                    <span class="status status-demo">
                        <span class="status-dot"></span>
                        <?= $db_status ?>
                    </span>
                    <?php else: ?>
                    <span class="status status-error">
                        <span class="status-dot"></span>
                        <?= $db_status ?>
                    </span>
                    <?php endif; ?>
                </div>
                <div class="info-row">
                    <span class="info-label">Engine</span>
                    <span class="info-value">MySQL<?= $demo_mode ? ' (Simulated)' : ' (RDS)' ?></span>
                </div>
                <div class="info-row">
                    <span class="info-label">Database</span>
                    <span class="info-value"><?= htmlspecialchars($db_name) ?></span>
                </div>
                <div class="info-row">
                    <span class="info-label">Host</span>
                    <span class="info-value"><?= htmlspecialchars(substr($db_host, 0, 30)) ?></span>
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
                    <div class="visit-label">Total Page Visits<?= $demo_mode ? ' (Simulated)' : '' ?></div>
                </div>
                <button class="refresh-btn" onclick="location.reload()">
                    🔄 Refresh Page
                </button>
            </div>
        </div>
        
        <footer>
            <p>Built with ❤️ for DevOps Portfolio | Environment: <?= $demo_mode ? 'Demo/Local' : 'Production' ?></p>
            <p style="margin-top: 0.5rem;">Refresh the page to see live updates</p>
        </footer>
    </div>
</body>
</html>
