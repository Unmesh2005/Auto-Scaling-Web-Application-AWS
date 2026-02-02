# 🚀 Deploy Your Auto-Scaling Demo

Quick guide to run your application locally or deploy to free hosting.

---

## Option 1: Local Testing with XAMPP

### Step 1: Download & Install XAMPP
1. Go to [apachefriends.org/download.html](https://www.apachefriends.org/download.html)
2. Download XAMPP for Windows
3. Install (default settings are fine)

### Step 2: Copy Files
```powershell
# Copy the standalone PHP file to XAMPP
copy "app\index_standalone.php" "C:\xampp\htdocs\index.php"
```

### Step 3: Start XAMPP
1. Open **XAMPP Control Panel**
2. Start **Apache** (and **MySQL** if you want database)
3. Open browser: `http://localhost/`

### Step 4: (Optional) Enable Database
1. Start MySQL in XAMPP Control Panel
2. Open phpMyAdmin: `http://localhost/phpmyadmin`
3. Create database: `devopsdb`
4. The app will auto-create the visits table!

---

## Option 2: Free Hosting (InfinityFree)

### Step 1: Create Account
1. Go to [infinityfree.net](https://www.infinityfree.net/)
2. Click "Sign Up" (free, no credit card)
3. Verify email

### Step 2: Create Website
1. Click "Create Account" in dashboard
2. Choose a subdomain (e.g., `yourname-devops.infinityfreeapp.com`)
3. Wait for activation (~10 minutes)

### Step 3: Upload Files
1. Go to **Control Panel** → **File Manager**
2. Navigate to `htdocs` folder
3. Upload `index_standalone.php` and rename to `index.php`

### Step 4: Create Database (Optional)
1. Go to **Control Panel** → **MySQL Databases**
2. Create database `devopsdb`
3. Note your database host, username, password
4. Update the credentials in your `index.php`

### Step 5: Access Your Site
Visit your subdomain URL - your app is live! 🎉

---

## Option 3: AWS Sandbox (Full Infrastructure)

For testing the complete AWS scripts:

| Platform | Cost | Link |
|----------|------|------|
| **AWS Free Tier** | Free (12 months) | [aws.amazon.com/free](https://aws.amazon.com/free/) |
| **AWS Educate** | Free credits for students | [aws.amazon.com/education/awseducate](https://aws.amazon.com/education/awseducate/) |
| **A Cloud Guru** | Subscription with sandboxes | [acloudguru.com](https://www.acloudguru.com/) |

---

## Quick Reference

| Deployment | Database | AWS Features | Time to Deploy |
|------------|----------|--------------|----------------|
| **Local (XAMPP)** | Optional | Demo Mode | 5 minutes |
| **InfinityFree** | Optional | Demo Mode | 15 minutes |
| **AWS Free Tier** | RDS MySQL | Full | 30 minutes |

---

## Files to Use

| File | Use Case |
|------|----------|
| `app/index_standalone.php` | Local testing, free hosting |
| `app/index.php` | AWS deployment only |

---

## Troubleshooting

### "Page shows PHP code instead of running"
- PHP isn't installed/configured
- Use XAMPP or a PHP hosting provider

### "Database connection error"
- That's OK! The app runs in Demo Mode
- Enable MySQL in XAMPP or use hosting database

### "Page not loading on InfinityFree"
- Wait 10-30 minutes after creating account
- Clear browser cache
