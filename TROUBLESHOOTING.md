# Troubleshooting Guide

This guide helps resolve common issues when setting up and running the "Wrong is the new Down" demo application.

## Common Issues

### 1. Django Fails to Start

#### Symptom
```
django.db.utils.OperationalError: connection to server at "localhost" (127.0.0.1), 
port 5432 failed: FATAL: database "demo_app" does not exist
```

#### Cause
PostgreSQL database not created or Django is trying to connect during startup.

#### Solution A: Create the database
```bash
sudo -u postgres psql -c "CREATE DATABASE demo_app OWNER postgres;"
```

#### Solution B: Use --noreload option
```bash
python manage.py runserver 0.0.0.0:8000 --noreload
```

The `--noreload` option prevents Django from checking database connections on startup.

---

### 2. Virtual Environment Not Activated

#### Symptom
```
ModuleNotFoundError: No module named 'django'
```

#### Cause
Virtual environment is not activated.

#### Solution
```bash
cd ~/wrong-is-new-down-demo
source venv/bin/activate

# You should see (venv) prefix in your prompt:
# (venv) user@host:~/wrong-is-new-down-demo$
```

**Important**: Always activate the virtual environment before running any Python commands.

---

### 3. PostgreSQL Connection Failed

#### Symptom
```
psycopg2.OperationalError: connection to server at "localhost" failed
```

#### Cause
PostgreSQL service not running or incorrect credentials.

#### Solution
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# If not running, start it
sudo systemctl start postgresql

# Enable auto-start on boot
sudo systemctl enable postgresql

# Verify database exists
sudo -u postgres psql -l | grep demo_app

# Reset password if needed
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
```

---

### 4. Permission Denied on Scripts

#### Symptom
```
bash: ./scripts/switch_to_normal.sh: Permission denied
```

#### Cause
Script files don't have execute permission.

#### Solution
```bash
chmod +x scripts/*.sh
```

---

### 5. Port 8000 Already in Use

#### Symptom
```
Error: That port is already in use.
```

#### Cause
Another Django instance or application is using port 8000.

#### Solution
```bash
# Find and kill the process using port 8000
sudo lsof -t -i:8000 | xargs kill -9

# Or use a different port
python manage.py runserver 0.0.0.0:8001 --noreload
```

---

### 6. CSRF Verification Failed

#### Symptom
```
403 Forbidden
CSRF verification failed. Request aborted.
```

#### Cause
CSRF token missing in POST request.

#### Solution

For browser testing: The HTML forms include `{% csrf_token %}` automatically.

For curl testing: Add `-H "X-CSRFToken: ..."` or use `--cookie` option:
```bash
# Get CSRF token first
curl -c cookies.txt http://localhost:8000/login/

# Use cookies in POST request
curl -b cookies.txt -X POST http://localhost:8000/login/ \
  -d "username=admin&password=yourpass"
```

Or disable CSRF for testing (NOT recommended for production):
```python
# In config/settings.py, comment out:
# 'django.middleware.csrf.CsrfViewMiddleware',
```

---

### 7. Superuser Not Created

#### Symptom
```
Invalid username or password (but you're sure credentials are correct)
```

#### Cause
Superuser was not created or migrations not run.

#### Solution
```bash
cd ~/wrong-is-new-down-demo/demo_app
source ../venv/bin/activate

# Run migrations first
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Follow prompts:
# Username: admin
# Email: admin@example.com
# Password: (your password)
# Password (again): (your password)
```

---

### 8. Database Migration Errors

#### Symptom
```
django.db.migrations.exceptions.InconsistentMigrationHistory
```

#### Cause
Database state inconsistent with migration files.

#### Solution
```bash
# Reset migrations (WARNING: This will delete all data)
sudo -u postgres psql -c "DROP DATABASE demo_app;"
sudo -u postgres psql -c "CREATE DATABASE demo_app OWNER postgres;"

cd ~/wrong-is-new-down-demo/demo_app
python manage.py migrate
python manage.py createsuperuser
```

---

### 9. Static Files Not Loading

#### Symptom
Web pages load but CSS/JavaScript missing, page looks unstyled.

#### Cause
Static files not collected or STATIC_ROOT not configured.

#### Solution
```bash
cd ~/wrong-is-new-down-demo/demo_app
python manage.py collectstatic --noinput
```

Note: For development, Django serves static files automatically when `DEBUG=True`.

---

### 10. HTTP 500 Error in Normal Mode

#### Symptom
Getting HTTP 500 even in normal mode when database is correct.

#### Cause
Python exception in views code or database query error.

#### Solution
```bash
# Check server logs
tail -f ~/wrong-is-new-down-demo/logs/server.log

# Or run Django in foreground to see errors
cd ~/wrong-is-new-down-demo/demo_app
python manage.py runserver 0.0.0.0:8000 --noreload

# Enable DEBUG mode to see detailed error
# In config/settings.py:
DEBUG = True
```

---

### 11. Scripts Don't Switch Modes

#### Symptom
Running `switch_to_problem.sh` but still getting HTTP 200.

#### Cause
- Virtual environment not activated
- Django server not restarting properly

#### Solution
```bash
# Activate virtual environment
cd ~/wrong-is-new-down-demo
source venv/bin/activate

# Kill any running Django processes
pkill -f "manage.py runserver"

# Run the script
./scripts/switch_to_problem.sh

# Verify the change
cat demo_app/login_app/db_utils.py | grep DB_NAME
# Should show: DB_NAME = 'wrong_demo_app'
```

---

### 12. Can't Access from Browser (Only localhost works)

#### Symptom
Can access http://localhost:8000 but not http://SERVER_IP:8000

#### Cause
Firewall blocking port 8000 or Django listening on 127.0.0.1 only.

#### Solution
```bash
# Check if Django is listening on 0.0.0.0
netstat -tuln | grep 8000
# Should show: 0.0.0.0:8000 (not 127.0.0.1:8000)

# If listening on 127.0.0.1, restart with 0.0.0.0:
python manage.py runserver 0.0.0.0:8000 --noreload

# Open firewall port (Ubuntu with ufw)
sudo ufw allow 8000/tcp
sudo ufw reload

# For AWS EC2, add Security Group rule:
# Type: Custom TCP
# Port: 8000
# Source: 0.0.0.0/0 (or your IP)
```

---

## Verification Checklist

Use this checklist to verify your setup:

- [ ] PostgreSQL is running: `sudo systemctl status postgresql`
- [ ] Database exists: `sudo -u postgres psql -l | grep demo_app`
- [ ] Virtual environment activated: `echo $VIRTUAL_ENV`
- [ ] Django installed: `python -c "import django; print(django.VERSION)"`
- [ ] Migrations applied: `python manage.py showmigrations`
- [ ] Superuser created: Try logging in via admin panel `/admin/`
- [ ] Server starts: `python manage.py runserver --noreload` (no errors)
- [ ] Home page accessible: `curl http://localhost:8000/`
- [ ] Login page accessible: `curl http://localhost:8000/login/`
- [ ] Scripts executable: `ls -l scripts/*.sh` (check for `x` permission)

---

## Debug Mode

To enable detailed error messages for troubleshooting:

```bash
cd ~/wrong-is-new-down-demo/demo_app

# Edit config/settings.py
# Set DEBUG = True

# Restart Django
pkill -f "manage.py runserver"
python manage.py runserver 0.0.0.0:8000 --noreload
```

With DEBUG=True, Django will show detailed error pages with:
- Full stack trace
- Variable values
- SQL queries
- Configuration settings

**Remember to set DEBUG=False before demonstrating to others.**

---

## Getting More Help

### View Server Logs
```bash
# Real-time log monitoring
tail -f ~/wrong-is-new-down-demo/logs/server.log

# View last 50 lines
tail -50 ~/wrong-is-new-down-demo/logs/server.log

# Search for errors
grep -i error ~/wrong-is-new-down-demo/logs/server.log
```

### Check Django Configuration
```bash
cd ~/wrong-is-new-down-demo/demo_app
python manage.py check
```

### Test Database Connection
```bash
cd ~/wrong-is-new-down-demo/demo_app
python manage.py dbshell
# Should open PostgreSQL prompt
# Type \q to exit
```

### Verify Python Environment
```bash
source ~/wrong-is-new-down-demo/venv/bin/activate
pip list
# Should show Django, psycopg2-binary
```

---

## Clean Reinstall

If all else fails, completely remove and reinstall:

```bash
# Stop Django
pkill -f "manage.py runserver"

# Remove project directory
rm -rf ~/wrong-is-new-down-demo

# Drop and recreate database
sudo -u postgres psql -c "DROP DATABASE IF EXISTS demo_app;"
sudo -u postgres psql -c "CREATE DATABASE demo_app OWNER postgres;"

# Re-run setup script
sudo ./setup_ec2.sh

# Follow setup steps from QUICKSTART.md
```

---

## Still Having Issues?

If you've tried the solutions above and still experiencing problems:

1. Check that your system meets the requirements (Ubuntu 22.04, Python 3.10+, PostgreSQL 14+)
2. Review the full setup in `SETUP.md`
3. Check the project's issue tracker for similar problems
4. Collect the following information for support:
   - Operating system version: `lsb_release -a`
   - Python version: `python --version`
   - PostgreSQL version: `psql --version`
   - Error messages from logs
   - Steps you've already tried

---

## Notes

- This is a demo application designed for testing environments
- Some issues may be expected behavior (e.g., HTTP 302 in problem mode)
- Always ensure virtual environment is activated before running commands
- Use `--noreload` option to prevent startup database checks
- Check logs first when troubleshooting: `tail -f logs/server.log`
