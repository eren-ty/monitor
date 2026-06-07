#!/usr/bin/env sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Edit webhook URLs and passwords before production use."
fi

DATA_DIR="$(
  awk -F= '/^[[:space:]]*MONITORING_DATA_DIR[[:space:]]*=/{print $2; exit}' .env 2>/dev/null \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//'
)"
DATA_DIR="${DATA_DIR:-/data/monitoring}"
if ! mkdir -p "$DATA_DIR/prometheus" "$DATA_DIR/alertmanager" "$DATA_DIR/grafana" "$DATA_DIR/consul" 2>/dev/null; then
  echo "Cannot create $DATA_DIR. Run: sudo ./scripts/prepare-data-dir.sh" >&2
  exit 1
fi

docker compose up -d --build
docker compose ps
