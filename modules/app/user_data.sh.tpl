#!/bin/bash
set -euo pipefail

mkdir -p /opt/portal

cat > /opt/portal/index.html << HTML
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Portal ${portal_version}</title></head>
<body>
<h1>Portal NexoAndes</h1>
<p>Version: ${portal_version}</p>
<p>Servidor: $(hostname)</p>
</body>
</html>
HTML

echo "ok" > /opt/portal/health
echo "${portal_version}" > /opt/portal/version

cat > /etc/systemd/system/portal.service << UNIT
[Unit]
Description=Portal NexoAndes
After=network.target

[Service]
WorkingDirectory=/opt/portal
ExecStart=/usr/bin/python3 -m http.server 80
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now portal
