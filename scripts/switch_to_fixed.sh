#!/bin/bash

#######################################
# Switch to Fixed Mode
# Django standard error handling (HTTP 500)
#######################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEMO_APP_DIR="$PROJECT_DIR/demo_app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔵 Switching to FIXED MODE (Proper Error Handling)"
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
echo "Step 1/4: Setting custom DB connection to correct database..."
cd "$DEMO_APP_DIR"
sed -i "s/DB_NAME = .*/DB_NAME = 'demo_app'  # Correct database name/" login_app/db_utils.py
echo "   ✅ Custom DB connection: demo_app"

# Step 2: Use AFTER version views (NO try-except)
echo "Step 2/4: Using AFTER version views (Django standard error handling)..."
cp login_app/views_after.py login_app/views.py
echo "   ✅ Views: AFTER version (no try-except, returns HTTP 500 on error)"

# Step 3: Set DEBUG=False for production-like error handling
echo "Step 3/4: Configuring Django for production error handling..."
sed -i "s/DEBUG = .*/DEBUG = False/" config/settings.py
sed -i "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" config/settings.py
echo "   ✅ Django DEBUG=False (production mode)"

# Step 4: Restart Django server
echo "Step 4/4: Restarting Django server..."
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
echo "✅ FIXED MODE Active (Proper Error Detection)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration:"
echo "  Django settings.py DB:  demo_app"
echo "  Custom DB connection:   demo_app ✅"
echo "  Error handling:         Django standard (no try-except)"
echo "  DEBUG:                  False (production mode)"
echo ""
echo "Expected Behavior:"
echo "  ✅ Login succeeds normally"
echo "  ✅ If database error occurs: HTTP 500 returned"
echo "  ✅ Monitoring tools can properly detect errors"
echo "  ✅ Proper alerting and incident response"
echo ""
echo "To test error scenario:"
echo "  1. Run: ./switch_to_problem.sh"
echo "  2. Then run: ./switch_to_fixed.sh"
echo "  3. Change DB name in db_utils.py to 'wrong_demo_app'"
echo "  4. Test: curl -i -X POST http://localhost:8000/login/ ..."
echo "  5. Observe HTTP 500 response (not HTTP 302)"
echo ""
