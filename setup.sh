#!/bin/bash

# BI Reporting Module - Setup and Run Script

echo "🚀 BI Reporting Module Setup"
echo "=============================="

# Check Python version
echo "📋 Checking Python version..."
python_version=$(python3 --version 2>&1)
echo "✅ Found: $python_version"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv .venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Create config file if it doesn't exist
if [ ! -f "app/config/database.ini" ]; then
    echo "⚙️  Creating database configuration..."
    cp app/config/database.ini.example app/config/database.ini
    echo "⚠️  Please edit app/config/database.ini with your database settings"
fi

# Create logs directory
mkdir -p logs

# Create data directories
mkdir -p data/exports

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Edit app/config/database.ini with your database settings"
echo "2. Run: python main.py"
echo ""
echo "🐳 For Docker deployment:"
echo "docker-compose up -d"
echo ""

# Option to run immediately
read -p "🚀 Run the application now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🎯 Starting BI Reporting Module..."
    python main.py
fi
