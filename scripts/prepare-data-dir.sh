#!/usr/bin/env sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"

DATA_DIR="$(
  awk -F= '/^[[:space:]]*MONITORING_DATA_DIR[[:space:]]*=/{print $2; exit}' .env 2>/dev/null \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//'
)"
DATA_DIR="${DATA_DIR:-/data/monitoring}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

mkdir -p "$DATA_DIR/prometheus" "$DATA_DIR/alertmanager" "$DATA_DIR/grafana" "$DATA_DIR/consul"

chown -R 65534:65534 "$DATA_DIR/prometheus" "$DATA_DIR/alertmanager"
chown -R 472:472 "$DATA_DIR/grafana"
chown -R 100:100 "$DATA_DIR/consul"

chmod 0755 "$DATA_DIR" "$DATA_DIR/prometheus" "$DATA_DIR/alertmanager" "$DATA_DIR/grafana" "$DATA_DIR/consul"

echo "Prepared data directories under $DATA_DIR"
