# Detailed Setup Guide

This guide provides comprehensive setup instructions for the "Wrong is the new Down" demonstration application.

## System Requirements

- **Operating System**: Ubuntu 22.04 LTS
- **Python**: 3.10 or higher
- **PostgreSQL**: 14 or higher
- **Memory**: Minimum 2GB RAM
- **Disk Space**: Minimum 5GB free space

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Django Application                        │
├─────────────────────────────────────────────────────────────┤
│  settings.py                                                 │
│  DATABASE_NAME: 'demo_app' (always correct)                 │
├─────────────────────────────────────────────────────────────┤
│  Custom DB Access Class (db_utils.py)                       │
│  DB_NAME: Configurable (can be wrong)                       │
├─────────────────────────────────────────────────────────────┤
│  Views                                                       │
│  ├─ views_before.py (try-except → HTTP 302)                │
│  └─ views_after.py  (Django standard → HTTP 500)           │
└─────────────────────────────────────────────────────────────┘
```

## Key Concept

The demo reproduces the "Wrong is the new Down" scenario by:

1. **Django's settings.py**: Always configured with correct database name
   - This ensures Django starts successfully
   - No startup errors occur

2. **Custom DB Access Class**: Uses its own database connection
   - Can be configured to connect to wrong database
   - Simulates real-world scenarios where custom connection logic exists

3. **Error Handling Versions**:
   - **BEFORE**: Catches errors and returns HTTP 302 (redirect)
   - **AFTER**: Lets errors propagate, returns HTTP 500 (proper error)

## Installation Steps

### Step 1: Automated Setup (Recommended)

```bash
# Download the setup script
curl -O https://raw.githubusercontent.com/YOUR_REPO/setup_ec2.sh

# Make it executable
chmod +x setup_ec2.sh

# Run the setup (requires sudo)
sudo ./setup_ec2.sh
```

The script will:
- Update system packages
- Install PostgreSQL
- Install Python dependencies
- Create PostgreSQL database and user
- Set up Python virtual environment
- Install Django and psycopg2

### Step 2: Django Setup

```bash
# Navigate to project directory
cd ~/wrong-is-new-down-demo

# Activate virtual environment
source venv/bin/activate

# Navigate to Django app
cd demo_app

# Run database migrations
python manage.py migrate

# Create a superuser for testing
python manage.py createsuperuser
# Follow the prompts to create username and password

# Start the development server
python manage.py runserver 0.0.0.0:8000 --noreload
```

**Important**: The `--noreload` option is required to prevent Django from checking database connections on startup.

### Step 3: Verify Installation

```bash
# In a new terminal, test the application
curl http://localhost:8000/

# You should see the home page HTML
```

## Manual Setup (Alternative)

If you prefer manual setup or the automated script fails:

### 1. Install System Dependencies

```bash
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib
sudo apt-get install -y python3-pip python3-venv python3-dev libpq-dev
```

### 2. Configure PostgreSQL

```bash
# Switch to postgres user
sudo -u postgres psql

# In PostgreSQL prompt, create user and database
CREATE USER postgres WITH PASSWORD 'postgres';
ALTER USER postgres WITH SUPERUSER;
CREATE DATABASE demo_app OWNER postgres;
\q
```

### 3. Set Up Python Environment

```bash
# Create project directory
mkdir -p ~/wrong-is-new-down-demo
cd ~/wrong-is-new-down-demo

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install Python packages
pip install Django==4.2 psycopg2-binary
```

### 4. Extract Demo Application

```bash
# Extract the demo application files to:
# ~/wrong-is-new-down-demo/demo_app/
```

### 5. Configure Environment

```bash
# Create .env file
cat > .env << EOF
DB_NAME=demo_app
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
DEBUG=True
SECRET_KEY=demo-secret-key-change-in-production
ALLOWED_HOSTS=*
CUSTOM_DB_NAME=demo_app
EOF
```

## Scenario Demonstration

### Scenario 1: Normal Operation

```bash
cd ~/wrong-is-new-down-demo
source venv/bin/activate
./scripts/switch_to_normal.sh

# Test login
curl -X POST http://localhost:8000/login/ \
  -d "username=admin&password=yourpassword"

# Expected: HTTP 200 OK
```

### Scenario 2: Problem Mode (Wrong is the new Down)

```bash
./scripts/switch_to_problem.sh

# Test login with detailed output
curl -i -X POST http://localhost:8000/login/ \
  -d "username=admin&password=yourpassword"

# Expected output:
# HTTP/1.1 302 Found
# Location: /500.html
# 
# Then browser automatically follows to /500.html
# HTTP/1.1 200 OK
# (500 error page content)
#
# Result: Monitoring tools see "302→200" = Normal!
```

### Scenario 3: Fixed Mode (Proper Error Detection)

```bash
./scripts/switch_to_fixed.sh

# Normal operation works fine
curl -X POST http://localhost:8000/login/ \
  -d "username=admin&password=yourpassword"

# Expected: HTTP 200 OK

# To test error scenario, manually change DB name in db_utils.py
# Then retry login:
# Expected: HTTP 500 Internal Server Error
```

## Understanding the Demo

### HTTP Status Code Flow

**Problem Mode (BEFORE)**:
```
POST /login/ → OperationalError
             → try-except catches
             → return HttpResponseRedirect('/500.html')
             → HTTP 302 Found

GET /500.html → custom_500_view()
              → render(..., status=200)
              → HTTP 200 OK

Monitoring tools: "302→200 = Normal operation" ✗
```

**Fixed Mode (AFTER)**:
```
POST /login/ → OperationalError
             → No try-except
             → Exception propagates to Django
             → Django returns HTTP 500
             → HTTP 500 Internal Server Error

Monitoring tools: "500 = Server error detected" ✓
```

## Instana Integration (Optional)

To see the full monitoring demonstration with IBM Instana:

### Install Instana Agent

```bash
# Contact your Instana administrator for agent installation
# Typically:
curl -o setup_agent.sh https://setup.instana.io/agent
sudo bash setup_agent.sh -a YOUR_AGENT_KEY -t dynamic -e YOUR_ENDPOINT
```

### Configure Instana

The demo automatically includes trace information. Instana will:

1. **Problem Mode**: Show HTTP 302 as normal (green status)
2. **Fixed Mode**: Show HTTP 500 as error (red status, alerts triggered)

## Troubleshooting

See `TROUBLESHOOTING.md` for common issues and solutions.

## File Structure

```
wrong-is-new-down-demo/
├── README.md                    # Overview
├── QUICKSTART.md                # 15-minute quick start
├── SETUP.md                     # This file
├── TROUBLESHOOTING.md          # Troubleshooting guide
├── setup_ec2.sh                # Automated setup script
├── .env                        # Environment variables
├── demo_app/                   # Django application
│   ├── manage.py
│   ├── config/
│   │   ├── settings.py         # Django settings (DB always correct)
│   │   ├── urls.py
│   │   └── wsgi.py
│   ├── login_app/
│   │   ├── views.py            # Current active views
│   │   ├── views_before.py     # BEFORE version (HTTP 302)
│   │   ├── views_after.py      # AFTER version (HTTP 500)
│   │   ├── db_utils.py         # Custom DB connection class
│   │   └── templates/
│   │       └── login_app/
│   │           ├── index.html
│   │           ├── login.html
│   │           └── 500.html
│   └── templates/
│       └── 500.html            # Django standard 500 page
├── scripts/
│   ├── switch_to_normal.sh     # Switch to normal mode
│   ├── switch_to_problem.sh    # Switch to problem mode
│   └── switch_to_fixed.sh      # Switch to fixed mode
└── logs/
    └── server.log              # Django server logs
```

## Security Considerations

This is a demonstration application and should NOT be used in production:

- Uses default credentials (`postgres`/`postgres`)
- Simplified authentication logic
- No HTTPS/SSL configuration
- DEBUG mode enabled by default
- No rate limiting or security hardening

## Next Steps

1. Review the code in `demo_app/login_app/` to understand the implementation
2. Test all three scenarios to see the different behaviors
3. Use browser Developer Tools (F12) to inspect HTTP status codes
4. Configure Instana to see the monitoring difference
5. Modify the code to experiment with different error handling approaches

## License

This is a demonstration application for educational purposes.

## Support

For questions or issues, please refer to `TROUBLESHOOTING.md` or contact the maintainer.
