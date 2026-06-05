#!/usr/bin/env sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SERVICE_NAME="monitoring-auto-update"
SYSTEMD_DIR="/etc/systemd/system"

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemd is required for this installer." >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

cat > "$SYSTEMD_DIR/$SERVICE_NAME.service" <<EOF
[Unit]
Description=Auto update Docker monitoring stack from Git
Wants=network-online.target
After=network-online.target docker.service

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/scripts/update.sh
EOF

cat > "$SYSTEMD_DIR/$SERVICE_NAME.timer" <<EOF
[Unit]
Description=Run monitoring Git auto update every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=10s
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME.timer"
systemctl list-timers "$SERVICE_NAME.timer"

