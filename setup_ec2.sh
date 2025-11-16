#!/bin/bash

#######################################
# Wrong is the new Down - Demo Setup Script
# For Ubuntu 22.04 LTS
#######################################

set -e  # Exit on error

echo "============================================"
echo "Wrong is the new Down - Demo Setup"
echo "============================================"
echo ""

# Check if running on Ubuntu
if [ ! -f /etc/lsb-release ]; then
    echo "Error: This script is designed for Ubuntu systems"
    exit 1
fi

# Update system packages
echo "Step 1/7: Updating system packages..."
sudo apt-get update -qq

# Install PostgreSQL
echo "Step 2/7: Installing PostgreSQL..."
sudo apt-get install -y -qq postgresql postgresql-contrib

# Install Python and dependencies
echo "Step 3/7: Installing Python dependencies..."
sudo apt-get install -y -qq python3-pip python3-venv python3-dev libpq-dev

# Configure PostgreSQL
echo "Step 4/7: Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE USER postgres WITH PASSWORD 'postgres';" 2>/dev/null || echo "User already exists"
sudo -u postgres psql -c "ALTER USER postgres WITH SUPERUSER;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE demo_app OWNER postgres;" 2>/dev/null || echo "Database already exists"

# Create project directory
echo "Step 5/7: Creating project directory..."
PROJECT_DIR="$HOME/wrong-is-new-down-demo"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create virtual environment
echo "Step 6/7: Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python packages
echo "Step 7/7: Installing Python packages..."
pip install --quiet --no-input Django==4.2 psycopg2-binary

# Create .env file
echo "Creating .env file..."
cat > .env << 'EOF'
# Database Configuration
DB_NAME=demo_app
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432

# Django Configuration
DEBUG=True
SECRET_KEY=demo-secret-key-change-in-production
ALLOWED_HOSTS=*

# Custom DB Access Class Configuration
CUSTOM_DB_NAME=demo_app
EOF

echo ""
echo "============================================"
echo "Setup completed successfully!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. cd $PROJECT_DIR"
echo "2. source venv/bin/activate"
echo "3. python manage.py migrate"
echo "4. python manage.py createsuperuser"
echo "5. python manage.py runserver 0.0.0.0:8000 --noreload"
echo ""
echo "IMPORTANT: Always activate virtual environment before running commands:"
echo "  source venv/bin/activate"
echo ""
