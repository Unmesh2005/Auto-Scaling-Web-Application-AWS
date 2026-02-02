@echo off
echo ========================================
echo   Auto-Scaling Web App - Local Setup
echo ========================================
echo.

REM Check if XAMPP is installed
if exist "C:\xampp\htdocs" (
    echo [OK] XAMPP found at C:\xampp
    echo.
    echo Copying index_standalone.php to htdocs...
    copy /Y "%~dp0app\index_standalone.php" "C:\xampp\htdocs\index.php"
    echo.
    echo [SUCCESS] File copied!
    echo.
    echo Next steps:
    echo   1. Open XAMPP Control Panel
    echo   2. Start Apache
    echo   3. Open http://localhost in your browser
    echo.
) else (
    echo [!] XAMPP not found!
    echo.
    echo Please install XAMPP first:
    echo   1. Download from: https://www.apachefriends.org/download.html
    echo   2. Install with default settings
    echo   3. Run this script again
    echo.
    echo Opening download page...
    start https://www.apachefriends.org/download.html
)

pause
