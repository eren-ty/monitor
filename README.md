# Prometheus + Grafana + Alertmanager 监控告警栈

这是一个基于 Docker Compose 的一键部署监控项目，包含 Prometheus、Grafana、Alertmanager、Node Exporter、cAdvisor、Blackbox Exporter，以及一个内置告警转发服务，用于把 Alertmanager 中文告警发送到钉钉和 Lark/飞书机器人。

## 组件

| 组件 | 地址 | 说明 |
| --- | --- | --- |
| Grafana | http://localhost:3000 | 默认账号来自 `.env` |
| Prometheus | http://localhost:9090 | 指标采集和告警规则 |
| Alertmanager | http://localhost:9093 | 告警聚合和分发 |
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

### 添加监控

添加一台服务器监控时，先在目标服务器部署 `node_exporter` 并开放 `9100` 端口，然后在本项目中修改：

```yaml
# prometheus/prometheus.yml
- job_name: node-servers
  static_configs:
    - targets:
        - 192.168.1.10:9100
        - 192.168.1.11:9100
```

重启 Prometheus：

```bash
docker compose restart prometheus
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

## 监控目标

默认采集：

- 当前宿主机指标：`node-exporter`
- Docker 容器指标：`cadvisor`
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
- 服务器防火墙只开放需要访问的端口。
- Linux 服务器更适合采集宿主机和容器指标；Docker Desktop 环境下部分宿主机挂载指标可能不完整。
