#!/usr/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Setup Volume
mkdir /data
mkfs.ext4 /dev/nvme1n1
mount /dev/nvme1n1 /data
mkdir -p /data/consensus
mkdir -p /data/execution

# Setup prometheus
groupadd --system prometheus
useradd -s /sbin/nologin --system -g prometheus prometheus
mkdir /var/lib/prometheus

for DIR in rules rules.d files_sd; do 
    mkdir -p /etc/prometheus/"${DIR}"
done

curl https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz \
    --location \
    --output /tmp/prometheus.tar.gz
tar -xzf /tmp/prometheus.tar.gz -C /tmp
mv /tmp/prometheus-2.45.0.linux-amd64/prometheus /usr/local/bin/
mv /tmp/prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/
mv /tmp/prometheus-2.45.0.linux-amd64/consoles /etc/prometheus
mv /tmp/prometheus-2.45.0.linux-amd64/console_libraries /etc/prometheus

cat > /etc/prometheus/prometheus.yml <<-EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
# Load and evaluate rules in this file every 'evaluation_interval' seconds.
rule_files:
  # - 'record.geth.rules.yml'
# A scrape configuration containing exactly one endpoint to scrape.
scrape_configs:
  - job_name: 'node_exporter'
    scrape_interval: 5s
    static_configs:
      - targets:
          - '127.0.0.1:9100'
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets:
          - '127.0.0.1:9090'
  - job_name: 'go-ethereum'
    scrape_interval: 5s
    metrics_path: /debug/metrics/prometheus
    static_configs:
      - targets:
          - '127.0.0.1:6060'
        labels:
          chain: ethereum
EOF

cat > /etc/systemd/system/prometheus.service <<-EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

for DIR in rules rules.d files_sd; do 
    chown -R prometheus:prometheus /etc/prometheus/"${DIR}"
    chmod -R 775 /etc/prometheus/"${DIR}"
done

chown -R prometheus:prometheus /var/lib/prometheus/

# Setup node_exporter
curl https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz \
    --location \
    --output /tmp/node_exporter.tar.gz
tar -xzf /tmp/node_exporter.tar.gz -C /tmp
mv /tmp/node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/

cat > /etc/systemd/system/node_exporter.service <<-EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/node_exporter

SyslogIdentifier=node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Setup grafana
curl -fsSL https://packages.grafana.com/gpg.key|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/grafana.gpg
add-apt-repository -y "deb https://packages.grafana.com/oss/deb stable main"
apt-get -y update
apt-get -y install grafana

# Setup geth
add-apt-repository -y ppa:ethereum/ethereum
apt-get -y update
apt-get -y install ethereum

cat > /etc/systemd/system/geth.service <<-EOF
[Unit]
Description=geth Ethereum Client

[Service]
ExecStart=geth \
    --authrpc.jwtsecret=/root/.jwt.hex \
    --datadir=/data/execution \
    --http \
    --http.addr=0.0.0.0 \
    --http.api=eth,net,engine,admin \
    --metrics \
    --metrics.addr=0.0.0.0 \
    --metrics.expensive
Restart=always
RestartSec=3
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# Setup prysm
mkdir /data/consensus/prysm
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh \
    --output /data/consensus/prysm/prysm.sh
chmod +x /data/consensus/prysm/prysm.sh

cat > /etc/systemd/system/prysm.service <<-EOF
[Unit]
Description=prysm Ethereum Client

[Service]
ExecStart=/data/consensus/prysm/prysm.sh \
    beacon-chain \
    --accept-terms-of-use \
    --checkpoint-sync-url=http://testing.mainnet.beacon-api.nimbus.team/ \
    --datadir=/data/consensus \
    --execution-endpoint=http://localhost:8551 \
    --genesis-beacon-api-url=http://testing.mainnet.beacon-api.nimbus.team/ \
    --grpc-gateway-host=0.0.0.0 \
    --jwt-secret=/root/.jwt.hex \
    --monitoring-host=0.0.0.0 \
    --rpc-host=0.0.0.0
Restart=always
RestartSec=3
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# Setup JWT
openssl rand -hex 32 | tr -d "\n" > /root/.jwt.hex

# Reload systemd
systemctl daemon-reload

# Start services
systemctl enable --now node_exporter.service
systemctl enable --now prometheus.service
systemctl enable --now grafana-server.service
systemctl enable --now geth.service
systemctl enable --now prysm.service

# Setup prometheus -> grafana data source
cat > /tmp/grafana_data_source.json <<-EOF
{
  "id": 1,
  "uid": "cdf413dd-c8c9-44bc-9371-de3df4b6efcc",
  "orgId": 1,
  "name": "Prometheus",
  "type": "prometheus",
  "typeName": "Prometheus",
  "typeLogoUrl": "public/app/plugins/datasource/prometheus/img/prometheus_logo.svg",
  "access": "proxy",
  "url": "http://localhost:9090",
  "user": "",
  "database": "",
  "basicAuth": false,
  "isDefault": true,
  "jsonData": {
    "httpMethod": "POST",
    "tlsSkipVerify": false
  },
  "readOnly": false
}
EOF

# Wait for grafana to start
while ! nc -z localhost 3000 ; do sleep 1 ; done

# Add prometheus data source to grafana
curl -X "POST" \
    "http://localhost:3000/api/datasources" \
    -H "Content-Type: application/json" \
    --user admin:admin \
    --data-binary @/tmp/grafana_data_source.json

# Workaround for 16K EC2 User Data limit (dashboard JSON is 30k uncompressed)
cat > /tmp/grafana_dashboard.json.gz.base64 <<-EOF
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
AA==
EOF

base64 --decode /tmp/grafana_dashboard.json.gz.base64 | gunzip > /tmp/grafana_dashboard.json

# Add prometheus dashboard to grafana
curl -X "POST" \
    "http://localhost:3000/api/dashboards/db" \
    -H "Content-Type: application/json" \
    --user admin:admin \
    --data-binary @/tmp/grafana_dashboard.json

echo "Ethereum Mainnet Node Bootstrap Complete!"