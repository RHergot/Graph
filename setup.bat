@echo off
REM BI Reporting Module - Windows Setup and Run Script

echo 🚀 BI Reporting Module Setup
echo ==============================

REM Check Python version
echo 📋 Checking Python version...
python --version
if %errorlevel% neq 0 (
    echo ❌ Python not found! Please install Python 3.8+ first.
    pause
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo 📦 Creating virtual environment...
    python -m venv .venv
)

REM Activate virtual environment
echo 🔧 Activating virtual environment...
call venv\Scripts\activate.bat

REM Upgrade pip
echo ⬆️  Upgrading pip...
python -m pip install --upgrade pip

REM Install dependencies
echo 📥 Installing dependencies...
pip install -r requirements.txt

REM Create config file if it doesn't exist
if not exist "app\config\database.ini" (
    echo ⚙️  Creating database configuration...
    copy "app\config\database.ini.example" "app\config\database.ini"
    echo ⚠️  Please edit app\config\database.ini with your database settings
)

REM Create directories
if not exist "logs" mkdir logs
if not exist "data\exports" mkdir data\exports

echo.
echo ✅ Setup complete!
echo.
echo 📋 Next steps:
echo 1. Edit app\config\database.ini with your database settings
echo 2. Run: python main.py
echo.
echo 🐳 For Docker deployment:
echo docker-compose up -d
echo.

REM Option to run immediately
set /p "run=🚀 Run the application now? (y/n): "
if /i "%run%"=="y" (
    echo 🎯 Starting BI Reporting Module...
    python main.py
)

pause
