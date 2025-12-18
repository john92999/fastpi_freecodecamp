#!/bin/bash
set -e

echo "========= FULL FASTAPI + POSTGRES SETUP START ========="

### VARIABLES ###
APP_USER="ubuntu1"
APP_DIR="/home/$APP_USER/app"
VENV_DIR="$APP_DIR/venv"
SERVICE_NAME="fastapi"
PORT=8000

DB_NAME="fastapi"
DB_USER="fastapi"
DB_PASS="fastapi123"
DB_HOST="localhost"
DB_PORT="5432"

### 1. UPDATE SYSTEM ###
sudo apt update -y

### 2. INSTALL REQUIRED PACKAGES ###
sudo apt install -y \
  python3 \
  python3-venv \
  python3-pip \
  git \
  nginx \
  ufw \
  postgresql \
  postgresql-contrib

### 3. ENABLE & START POSTGRES ###
sudo systemctl enable postgresql
sudo systemctl start postgresql

### 4. CREATE DATABASE & USER (SAFE) ###
sudo -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME') THEN
      CREATE DATABASE $DB_NAME;
   END IF;
END
\$\$;

DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
   END IF;
END
\$\$;

ALTER DATABASE $DB_NAME OWNER TO $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

### 5. POSTGRES LISTEN CONFIG ###
PG_CONF=$(sudo -u postgres psql -t -P format=unaligned -c "show config_file;")
PG_HBA=$(sudo -u postgres psql -t -P format=unaligned -c "show hba_file;")

sudo sed -i "s/#listen_addresses =.*/listen_addresses = '*'/" $PG_CONF

sudo sed -i '/^host\s\+all\s\+all\s\+0.0.0.0\/0/d' $PG_HBA
echo "host all all 0.0.0.0/0 scram-sha-256" | sudo tee -a $PG_HBA

sudo systemctl restart postgresql

### 6. FIREWALL ###
sudo ufw allow OpenSSH || true
sudo ufw allow 80 || true
sudo ufw allow $PORT || true
sudo ufw --force enable || true

### 7. APP DIRECTORY ###
mkdir -p "$APP_DIR"
cd "$APP_DIR"

### 8. PYTHON VENV ###
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip setuptools wheel

### 9. INSTALL PYTHON DEPENDENCIES ###
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
else
  pip install fastapi uvicorn gunicorn psycopg2-binary sqlalchemy alembic python-dotenv
fi

### 10. CREATE .ENV ###
cat > "$APP_DIR/.env" <<EOF
DATABASE_HOSTNAME=$DB_HOST
DATABASE_PORT=$DB_PORT
DATABASE_USERNAME=$DB_USER
DATABASE_PASSWORD=$DB_PASS
DATABASE_NAME=$DB_NAME
SECRET_KEY=supersecretkey
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
EOF

### 11. RUN ALEMBIC MIGRATIONS ###
if [ -f alembic.ini ]; then
  alembic upgrade head || true
fi

### 12. SYSTEMD SERVICE ###
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=FastAPI Application
After=network.target

[Service]
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn \
  -k uvicorn.workers.UvicornWorker \
  -b 0.0.0.0:$PORT \
  app.main:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

### 13. NGINX CONFIG ###
sudo tee /etc/nginx/sites-available/fastapi > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/fastapi

sudo nginx -t
sudo systemctl restart nginx

echo "========= SETUP COMPLETE ========="
echo "App running at: http://SERVER_IP"
