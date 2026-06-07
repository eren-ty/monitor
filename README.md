# Prometheus + Grafana + Alertmanager 监控告警栈

这是一个基于 Docker Compose 的一键部署监控项目，包含 Prometheus、Grafana、Alertmanager、Consul、Node Exporter、cAdvisor、Blackbox Exporter，以及一个内置告警转发服务，用于把 Alertmanager 中文告警发送到钉钉和 Lark/飞书机器人。

## 组件

| 组件 | 地址 | 说明 |
| --- | --- | --- |
| Grafana | http://localhost:3000 | 默认账号来自 `.env` |
| Prometheus | http://localhost:9090 | 指标采集和告警规则 |
| Alertmanager | http://localhost:9093 | 告警聚合和分发 |
| Consul | http://localhost:8500 | 服务发现和节点注册 |
| Webhook Relay | http://localhost:8080/healthz | 钉钉和 Lark 告警转发 |

## 快速部署

服务器需要先安装 Docker 和 Docker Compose 插件。

首次部署推荐流程：

```bash
git clone https://github.com/eren-ty/monitor.git
cd monitor
cp .env.example .env
vim .env
sudo ./scripts/prepare-data-dir.sh
./scripts/deploy.sh
```

或使用 Makefile：

```bash
make deploy
```

部署后访问：

- Grafana: `http://服务器IP:3000`
- Prometheus: `http://服务器IP:9090`
- Alertmanager: `http://服务器IP:9093`
- Consul: `http://服务器IP:8500`

## 部署与维护手册

### 首次部署

1. 安装 Docker 和 Docker Compose 插件。
2. 克隆项目：

```bash
git clone https://github.com/eren-ty/monitor.git
cd monitor
```

3. 初始化环境变量：

```bash
cp .env.example .env
vim .env
```

重点修改：

- `GRAFANA_ADMIN_PASSWORD`
- `DINGTALK_WEBHOOK_URL`
- `DINGTALK_SECRET`
- `LARK_WEBHOOK_URL`
- `LARK_SECRET`
- `MONITORING_DATA_DIR`
- `CONSUL_DATACENTER`
- `CONSUL_ADVERTISE_ADDR`

如果需要其他服务器通过 Consul 自动注册，`CONSUL_ADVERTISE_ADDR` 必须设置为监控服务器的内网 IP，例如：

```bash
CONSUL_ADVERTISE_ADDR=192.168.1.100
```

4. 准备数据目录：

```bash
sudo ./scripts/prepare-data-dir.sh
```

5. 启动服务：

```bash
./scripts/deploy.sh
```

### 日常维护

查看服务：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f --tail=200
```

重启服务：

```bash
docker compose restart
```

停止服务：

```bash
docker compose down
```

重新构建并启动：

```bash
docker compose up -d --build
```

也可以使用项目内置命令：

```bash
make ps
make logs
make restart
make down
make deploy
make update
```

建议定期备份：

```bash
/data/monitoring
.env
```

### 修改配置

修改 Prometheus 采集目标：

```bash
vim prometheus/prometheus.yml
docker compose restart prometheus
```

修改告警规则：

```bash
vim prometheus/alert.rules.yml
docker compose restart prometheus
```

新增扩展告警规则：

```bash
vim prometheus/rules/service.rules.yml
docker compose restart prometheus
```

修改 Alertmanager 分组、静默、重复发送间隔：

```bash
vim alertmanager/alertmanager.yml
docker compose restart alertmanager
```

修改钉钉或 Lark/飞书机器人：

```bash
vim .env
docker compose up -d --build alert-webhook
```

### 更新版本

手动同步 GitHub 最新代码：

```bash
git pull
./scripts/deploy.sh
```

启用自动更新部署：

```bash
sudo ./scripts/install-auto-update.sh
```

启用后会每分钟检查 Git，有新提交时自动执行：

```bash
git pull
docker compose pull
docker compose up -d --build --remove-orphans
```

查看自动更新日志：

```bash
journalctl -u monitoring-auto-update.service -n 100 --no-pager
```

### 添加服务器监控

本项目使用 Consul 做服务发现。Prometheus 通过 `consul_sd_configs` 自动发现注册到 Consul 的 `node-exporter` 服务，新增服务器不需要修改 `prometheus/prometheus.yml`。

监控服务器 `.env` 中建议先设置：

```bash
CONSUL_ADVERTISE_ADDR=监控服务器内网IP
```

监控服务器需要开放这些端口给被监控服务器：

```text
8300/tcp    Consul RPC
8301/tcp    Consul LAN gossip
8301/udp    Consul LAN gossip
8500/tcp    Consul UI/API，可按需限制来源
```

Prometheus 抓取远程 `node_exporter` 时，监控服务器还需要能访问被监控服务器：

```text
9100/tcp    node_exporter
```

在被监控服务器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/eren-ty/monitor/main/scripts/install-node-exporter-consul.sh -o install-node-exporter-consul.sh
sudo CONSUL_SERVER=监控服务器IP NODE_ENV=prod NODE_NAME=web-01 sh install-node-exporter-consul.sh
```

参数说明：

- `CONSUL_SERVER`: 监控服务器 IP，必填。
- `NODE_ENV`: 环境标签，例如 `prod`、`test`、`dev`。
- `NODE_NAME`: 节点名称，建议使用业务主机名。
- `ADVERTISE_ADDR`: 当前服务器被 Prometheus 访问的 IP，不填时脚本自动取第一个本机 IP。
- `CONSUL_DATACENTER`: Consul 数据中心名称，默认 `dc1`。

注册成功后可以在 Consul UI 查看：

```text
http://监控服务器IP:8500
```

Prometheus targets 页面会自动出现 `consul-node-exporter`：

```text
http://监控服务器IP:9090/targets
```

删除某台服务器时，在被监控服务器停止 agent：

```bash
cd /opt/monitor-agent
docker compose down
```

添加 HTTP/HTTPS 地址探测：

```yaml
# prometheus/prometheus.yml
- job_name: blackbox-http
  static_configs:
    - targets:
        - https://你的域名
        - https://api.example.com/health
```

重启 Prometheus：

```bash
docker compose restart prometheus
```

### 推荐变更流程

```bash
git pull
vim prometheus/prometheus.yml
vim prometheus/alert.rules.yml
vim prometheus/rules/service.rules.yml
ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }' prometheus/prometheus.yml prometheus/alert.rules.yml prometheus/rules/service.rules.yml
git add .
git commit -m "update monitor config"
git push
./scripts/deploy.sh
```

## 告警配置

编辑 `.env`：

```bash
DINGTALK_WEBHOOK_URL=https://oapi.dingtalk.com/robot/send?access_token=xxxx
DINGTALK_SECRET=xxxx
LARK_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/xxxx
LARK_SECRET=xxxx
```

如果机器人没有开启签名校验，对应 `*_SECRET` 可以留空。

Alertmanager 默认会把所有告警发给 `alert-webhook` 服务，再由它转发到钉钉和 Lark。基础告警规则在 `prometheus/alert.rules.yml`，扩展规则放在 `prometheus/rules/*.yml`。

告警消息默认使用中文字段：

- 告警名称
- 告警级别
- 当前状态
- 监控任务
- 实例地址
- 触发时间 / 恢复时间
- 告警摘要
- 告警描述

标题前缀可通过 `.env` 调整：

```bash
ALERT_TITLE_PREFIX=监控告警
```

扩展规则文件示例：

```yaml
groups:
  - name: service.rules
    rules:
      - alert: ServiceDown
        expr: up{job="node-servers"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "服务 {{ $labels.instance }} 不可用"
          description: "监控任务 {{ $labels.job }} 的目标已连续 1 分钟不可达。"
```

## 数据持久化

Prometheus、Alertmanager、Grafana 的数据默认挂载到宿主机 `/data/monitoring`：

```text
/data/monitoring/prometheus
/data/monitoring/alertmanager
/data/monitoring/grafana
/data/monitoring/consul
```

如需改成其他目录，编辑 `.env`：

```bash
MONITORING_DATA_DIR=/data/monitoring
```

首次部署前执行：

```bash
sudo ./scripts/prepare-data-dir.sh
```

该脚本会创建数据目录，并设置容器运行用户所需权限：

- Prometheus / Alertmanager: `65534:65534`
- Grafana: `472:472`
- Consul: `100:100`

## 监控目标

默认采集：

- 当前宿主机指标：`node-exporter`
- Docker 容器指标：`cadvisor`
- Consul 自动注册的远程服务器：`consul-node-exporter`
- Prometheus、Alertmanager 自身指标
- Blackbox HTTP 探测示例：`https://example.com`

修改 HTTP 探测目标：

```yaml
# prometheus/prometheus.yml
- job_name: blackbox-http
  static_configs:
    - targets:
        - https://你的域名
```

修改后执行：

```bash
docker compose restart prometheus
```

## Git 推送

首次推送到远程仓库：

```bash
git init
git add .
git commit -m "init monitoring stack"
git branch -M main
git remote add origin <你的Git仓库地址>
git push -u origin main
```

如果当前目录已经是 Git 仓库，只需要：

```bash
git add .
git commit -m "update monitoring stack"
git push
```

## Git 自动更新部署

推荐在部署服务器上使用 systemd 定时器，每分钟检查远程 Git 是否有更新，有更新就自动执行 `docker compose pull && docker compose up -d --build --remove-orphans`。

```bash
sudo ./scripts/install-auto-update.sh
```

查看定时器：

```bash
systemctl list-timers monitoring-auto-update.timer
```

查看更新日志：

```bash
journalctl -u monitoring-auto-update.service -n 100 --no-pager
```

如果你只想在手动 `git pull` 后自动重启，可以安装 post-merge hook：

```bash
./scripts/install-post-merge-hook.sh
```

## 常用命令

```bash
make ps
make logs
make restart
make update
make down
make validate
```

## 目录结构

```text
.
├── alertmanager/
├── blackbox/
├── grafana/
├── prometheus/
│   └── rules/
├── scripts/
├── webhook-relay/
├── docker-compose.yml
├── .env.example
└── Makefile
```

## 生产建议

- 修改 Grafana 默认密码。
- 不要把 `.env` 提交到 Git。
- 定期备份 `/data/monitoring`。
- 服务器防火墙只开放需要访问的端口，尤其是 Consul 的 `8300`、`8301`、`8500` 和 node_exporter 的 `9100`。
- 如果服务器跨公网通信，建议使用内网、VPN 或安全组限制 Consul 和 node_exporter 访问来源。
- Linux 服务器更适合采集宿主机和容器指标；Docker Desktop 环境下部分宿主机挂载指标可能不完整。
