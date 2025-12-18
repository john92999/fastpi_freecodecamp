#!/bin/bash

set -e

# ===============================
# Prompt for application IP
# ===============================
read -p "Enter the application IP to monitor (app_ip): " APP_IP

# Get server IP
MONITORING_IP=$(hostname -I | awk '{print $1}')
echo "Monitoring server IP detected as: $MONITORING_IP"

# ===============================
# Install required packages
# ===============================
sudo apt update -y
sudo apt install wget tar ufw -y

# ===============================
# Create users
# ===============================
sudo useradd --no-create-home --shell /usr/sbin/nologin prometheus || true
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true
sudo useradd --no-create-home --shell /usr/sbin/nologin blackbox || true

# ===============================
# Setup directories
# ===============================
sudo mkdir -p /usr/local/prometheus
sudo mkdir -p /usr/local/node_exporter
sudo mkdir -p /usr/local/blackbox_exporter
sudo mkdir -p /etc/prometheus

# ===============================
# Download and setup Prometheus
# ===============================
PROM_VERSION="2.51.0"
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz
tar xvf /tmp/prometheus.tar.gz -C /tmp/
sudo cp /tmp/prometheus-${PROM_VERSION}.linux-amd64/prometheus /usr/local/prometheus/
sudo cp /tmp/prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/prometheus/
sudo cp -r /tmp/prometheus-${PROM_VERSION}.linux-amd64/consoles /usr/local/prometheus/
sudo cp -r /tmp/prometheus-${PROM_VERSION}.linux-amd64/console_libraries /usr/local/prometheus/

# Prometheus config
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['$MONITORING_IP:9100']

  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - http://$APP_IP:8000/health
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: $MONITORING_IP:9115
EOF

sudo chown -R prometheus:prometheus /usr/local/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus

# ===============================
# Setup Prometheus systemd
# ===============================
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Server
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/prometheus/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/usr/local/prometheus/data

[Install]
WantedBy=multi-user.target
EOF

# ===============================
# Download Node Exporter
# ===============================
NODE_VER="1.7.1"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_VER}/node_exporter-${NODE_VER}.linux-amd64.tar.gz -O /tmp/node_exporter.tar.gz
tar xvf /tmp/node_exporter.tar.gz -C /tmp/
sudo cp /tmp/node_exporter-${NODE_VER}.linux-amd64/node_exporter /usr/local/node_exporter/
sudo chown node_exporter:node_exporter /usr/local/node_exporter/node_exporter
sudo chmod +x /usr/local/node_exporter/node_exporter

# Node Exporter systemd
cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/node_exporter/node_exporter --web.listen-address="0.0.0.0:9100"

[Install]
WantedBy=multi-user.target
EOF

# ===============================
# Download Blackbox Exporter
# ===============================
BB_VER="0.24.0"
wget https://github.com/prometheus/blackbox_exporter/releases/download/v${BB_VER}/blackbox_exporter-${BB_VER}.linux-amd64.tar.gz -O /tmp/blackbox_exporter.tar.gz
tar xvf /tmp/blackbox_exporter.tar.gz -C /tmp/
sudo cp /tmp/blackbox_exporter-${BB_VER}.linux-amd64/blackbox_exporter /usr/local/blackbox_exporter/

# Blackbox config
cat <<EOF | sudo tee /usr/local/blackbox_exporter/blackbox.yml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: [ "HTTP/1.1", "HTTP/2.0" ]
      valid_status_codes: []
      method: GET
EOF

sudo chown -R blackbox:blackbox /usr/local/blackbox_exporter
sudo chmod 755 /usr/local/blackbox_exporter/blackbox_exporter
sudo chmod 644 /usr/local/blackbox_exporter/blackbox.yml

# Blackbox Exporter systemd
cat <<EOF | sudo tee /etc/systemd/system/blackbox_exporter.service
[Unit]
Description=Blackbox Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=blackbox
Group=blackbox
Type=simple
ExecStart=/usr/local/blackbox_exporter/blackbox_exporter --config.file=/usr/local/blackbox_exporter/blackbox.yml --web.listen-address="0.0.0.0:9115"

[Install]
WantedBy=multi-user.target
EOF

# ===============================
# Reload systemd and start services
# ===============================
sudo systemctl daemon-reload
sudo systemctl enable prometheus node_exporter blackbox_exporter
sudo systemctl start prometheus node_exporter blackbox_exporter

# ===============================
# Open firewall ports
# ===============================
sudo ufw allow 9090/tcp
sudo ufw allow 9100/tcp
sudo ufw allow 9115/tcp
sudo ufw reload

# ===============================
# Done
# ===============================
echo "=============================="
echo "Setup complete!"
echo "Prometheus: http://$MONITORING_IP:9090"
echo "Node Exporter: http://$MONITORING_IP:9100/metrics"
echo "Blackbox Exporter: http://$MONITORING_IP:9115/metrics"
echo "Prometheus is configured to scrape your app at: http://$APP_IP:8000/health"
echo "=============================="
