#!/bin/bash

#######################################
# Switch to Normal Mode
# System works correctly (HTTP 200)
#######################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEMO_APP_DIR="$PROJECT_DIR/demo_app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢 Switching to NORMAL MODE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if virtual environment exists
if [ ! -d "$PROJECT_DIR/venv" ]; then
    echo "⚠️  Virtual environment not found!"
    echo "   Please run setup_ec2.sh first"
    exit 1
fi

# Reminder to activate virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    echo "⚠️  REMINDER: Activate virtual environment first!"
    echo "   Run: source venv/bin/activate"
    echo ""
fi

# Step 1: Set custom DB access class to correct database name
echo "Step 1/3: Setting custom DB connection to correct database..."
cd "$DEMO_APP_DIR"
sed -i "s/DB_NAME = .*/DB_NAME = 'demo_app'  # Correct database name/" login_app/db_utils.py
echo "   ✅ Custom DB connection: demo_app"

# Step 2: Use BEFORE version views (with try-except, but won't be triggered)
echo "Step 2/3: Using BEFORE version views (try-except sleeping)..."
cp login_app/views_before.py login_app/views.py
echo "   ✅ Views: BEFORE version (with try-except handler)"

# Step 3: Restart Django server
echo "Step 3/3: Restarting Django server..."
pkill -f "manage.py runserver" 2>/dev/null || true
sleep 2

if [ -n "$VIRTUAL_ENV" ]; then
    nohup python manage.py runserver 0.0.0.0:8000 --noreload > ../logs/server.log 2>&1 &
    sleep 3
    echo "   ✅ Django server restarted"
else
    echo "   ⚠️  Server not started (virtual environment not activated)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ NORMAL MODE Active"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration:"
echo "  Django settings.py DB:  demo_app"
echo "  Custom DB connection:   demo_app ✅"
echo "  Error handling:         try-except (sleeping 💤)"
echo ""
echo "Expected Behavior:"
echo "  ✅ Login succeeds"
echo "  ✅ HTTP 200 OK"
echo "  ✅ Monitoring tools see normal operation"
echo ""
echo "Test with:"
echo "  curl -X POST http://localhost:8000/login/ -d 'username=admin&password=yourpass'"
echo ""
