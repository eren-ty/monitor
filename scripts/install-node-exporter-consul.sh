#!/usr/bin/env sh
set -eu

INSTALL_DIR="${INSTALL_DIR:-/opt/monitor-agent}"
CONSUL_DATACENTER="${CONSUL_DATACENTER:-dc1}"
NODE_ENV="${NODE_ENV:-prod}"
NODE_NAME="${NODE_NAME:-$(hostname)}"
CONSUL_SERVER="${CONSUL_SERVER:-}"
ADVERTISE_ADDR="${ADVERTISE_ADDR:-}"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo CONSUL_SERVER=<monitor-server-ip> $0" >&2
  exit 1
fi

if [ -z "$CONSUL_SERVER" ]; then
  echo "CONSUL_SERVER is required, for example: sudo CONSUL_SERVER=192.168.1.100 $0" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required on this node." >&2
  exit 1
fi

if [ -z "$ADVERTISE_ADDR" ]; then
  ADVERTISE_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi

if [ -z "$ADVERTISE_ADDR" ]; then
  echo "Cannot detect ADVERTISE_ADDR. Set it explicitly." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR/consul" "$INSTALL_DIR/consul.d"
chown -R 100:100 "$INSTALL_DIR/consul"

cat > "$INSTALL_DIR/.env" <<EOF
CONSUL_SERVER=$CONSUL_SERVER
CONSUL_DATACENTER=$CONSUL_DATACENTER
NODE_ENV=$NODE_ENV
NODE_NAME=$NODE_NAME
ADVERTISE_ADDR=$ADVERTISE_ADDR
EOF

cat > "$INSTALL_DIR/consul.d/node-exporter.hcl" <<EOF
service {
  id = "node-exporter-$NODE_NAME"
  name = "node-exporter"
  tags = ["node", "$NODE_ENV"]
  address = "$ADVERTISE_ADDR"
  port = 9100

  meta = {
    env = "$NODE_ENV"
    hostname = "$NODE_NAME"
  }

  check {
    id = "node-exporter-tcp"
    name = "node_exporter tcp check"
    tcp = "$ADVERTISE_ADDR:9100"
    interval = "15s"
    timeout = "3s"
  }
}
EOF

cat > "$INSTALL_DIR/docker-compose.yml" <<'EOF'
services:
  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: monitor-agent-node-exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    command:
      - --path.rootfs=/host
    volumes:
      - /:/host:ro,rslave

  consul-agent:
    image: hashicorp/consul:1.20
    container_name: monitor-agent-consul
    restart: unless-stopped
    network_mode: host
    command:
      - agent
      - -datacenter=${CONSUL_DATACENTER}
      - -node=${NODE_NAME}
      - -retry-join=${CONSUL_SERVER}
      - -advertise=${ADVERTISE_ADDR}
      - -client=127.0.0.1
      - -data-dir=/consul/data
      - -config-dir=/consul/config
    volumes:
      - ./consul:/consul/data
      - ./consul.d:/consul/config:ro
EOF

cd "$INSTALL_DIR"
docker compose up -d
docker compose ps

echo "Registered node_exporter through Consul: $NODE_NAME $ADVERTISE_ADDR:9100 env=$NODE_ENV"
