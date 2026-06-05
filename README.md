# Prometheus + Grafana + Alertmanager 监控告警栈

这是一个基于 Docker Compose 的一键部署监控项目，包含 Prometheus、Grafana、Alertmanager、Node Exporter、cAdvisor、Blackbox Exporter，以及一个内置告警转发服务，用于把 Alertmanager 告警发送到钉钉和 Lark/飞书机器人。

## 组件

| 组件 | 地址 | 说明 |
| --- | --- | --- |
| Grafana | http://localhost:3000 | 默认账号来自 `.env` |
| Prometheus | http://localhost:9090 | 指标采集和告警规则 |
| Alertmanager | http://localhost:9093 | 告警聚合和分发 |
| Webhook Relay | http://localhost:8080/healthz | 钉钉和 Lark 告警转发 |

## 快速部署

服务器需要先安装 Docker 和 Docker Compose 插件。

```bash
cp .env.example .env
vim .env
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

## 告警配置

编辑 `.env`：

```bash
DINGTALK_WEBHOOK_URL=https://oapi.dingtalk.com/robot/send?access_token=xxxx
DINGTALK_SECRET=xxxx
LARK_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/xxxx
LARK_SECRET=xxxx
```

如果机器人没有开启签名校验，对应 `*_SECRET` 可以留空。

Alertmanager 默认会把所有告警发给 `alert-webhook` 服务，再由它转发到钉钉和 Lark。告警规则在 `prometheus/alert.rules.yml`。

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
├── scripts/
├── webhook-relay/
├── docker-compose.yml
├── .env.example
└── Makefile
```

## 生产建议

- 修改 Grafana 默认密码。
- 不要把 `.env` 提交到 Git。
- 服务器防火墙只开放需要访问的端口。
- Linux 服务器更适合采集宿主机和容器指标；Docker Desktop 环境下部分宿主机挂载指标可能不完整。

