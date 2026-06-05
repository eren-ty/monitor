import base64
import hashlib
import hmac
import os
import time
import urllib.parse

import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

DINGTALK_WEBHOOK_URL = os.getenv("DINGTALK_WEBHOOK_URL", "")
DINGTALK_SECRET = os.getenv("DINGTALK_SECRET", "")
LARK_WEBHOOK_URL = os.getenv("LARK_WEBHOOK_URL", "")
LARK_SECRET = os.getenv("LARK_SECRET", "")
ALERT_TITLE_PREFIX = os.getenv("ALERT_TITLE_PREFIX", "Monitoring Alert")

STATUS_TEXT = {
    "firing": "触发中",
    "resolved": "已恢复",
}

SEVERITY_TEXT = {
    "critical": "严重",
    "warning": "警告",
    "info": "提示",
}


def build_markdown(payload):
    status = payload.get("status", "unknown")
    status_text = STATUS_TEXT.get(status, status)
    alerts = payload.get("alerts", [])
    title = f"{ALERT_TITLE_PREFIX} [{status_text}] {payload.get('groupKey', '')}".strip()
    lines = [f"### {title}", ""]

    for alert in alerts:
        labels = alert.get("labels", {})
        annotations = alert.get("annotations", {})
        alert_name = labels.get("alertname", "未知告警")
        severity = labels.get("severity", "unknown")
        severity_text = SEVERITY_TEXT.get(severity, severity)
        instance = labels.get("instance", "-")
        job = labels.get("job", "-")
        summary = annotations.get("summary", "")
        description = annotations.get("description", "")
        starts_at = alert.get("startsAt", "")
        ends_at = alert.get("endsAt", "")
        alert_status = alert.get("status", status)
        alert_status_text = STATUS_TEXT.get(alert_status, alert_status)

        lines.extend(
            [
                f"- **告警名称**: {alert_name}",
                f"- **告警级别**: {severity_text}",
                f"- **当前状态**: {alert_status_text}",
                f"- **监控任务**: {job}",
                f"- **实例地址**: {instance}",
                f"- **触发时间**: {starts_at or '-'}",
            ]
        )
        if alert_status == "resolved":
            lines.append(f"- **恢复时间**: {ends_at or '-'}")
        if summary:
            lines.append(f"- **告警摘要**: {summary}")
        if description:
            lines.append(f"- **告警描述**: {description}")
        lines.append("")

    return title[:120], "\n".join(lines)


def dingtalk_signed_url():
    if not DINGTALK_SECRET:
        return DINGTALK_WEBHOOK_URL

    timestamp = str(round(time.time() * 1000))
    string_to_sign = f"{timestamp}\n{DINGTALK_SECRET}".encode("utf-8")
    digest = hmac.new(
        DINGTALK_SECRET.encode("utf-8"),
        string_to_sign,
        digestmod=hashlib.sha256,
    ).digest()
    sign = urllib.parse.quote_plus(base64.b64encode(digest))
    separator = "&" if "?" in DINGTALK_WEBHOOK_URL else "?"
    return f"{DINGTALK_WEBHOOK_URL}{separator}timestamp={timestamp}&sign={sign}"


def lark_signature(timestamp):
    string_to_sign = f"{timestamp}\n{LARK_SECRET}".encode("utf-8")
    digest = hmac.new(string_to_sign, b"", digestmod=hashlib.sha256).digest()
    return base64.b64encode(digest).decode("utf-8")


def send_dingtalk(title, markdown):
    if not DINGTALK_WEBHOOK_URL:
        return None

    body = {
        "msgtype": "markdown",
        "markdown": {
            "title": title,
            "text": markdown,
        },
    }
    response = requests.post(dingtalk_signed_url(), json=body, timeout=10)
    response.raise_for_status()
    return response.json()


def send_lark(title, markdown):
    if not LARK_WEBHOOK_URL:
        return None

    template = "green" if title.find("已恢复") >= 0 else "red"
    body = {
        "msg_type": "interactive",
        "card": {
            "header": {
                "title": {
                    "tag": "plain_text",
                    "content": title,
                },
                "template": template,
            },
            "elements": [
                {
                    "tag": "markdown",
                    "content": markdown,
                }
            ],
        },
    }
    if LARK_SECRET:
        timestamp = str(int(time.time()))
        body["timestamp"] = timestamp
        body["sign"] = lark_signature(timestamp)

    response = requests.post(LARK_WEBHOOK_URL, json=body, timeout=10)
    response.raise_for_status()
    return response.json()


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.post("/alertmanager")
def alertmanager():
    payload = request.get_json(force=True, silent=False)
    title, markdown = build_markdown(payload)
    results = {}

    for name, sender in (("dingtalk", send_dingtalk), ("lark", send_lark)):
        try:
            results[name] = sender(title, markdown)
        except Exception as exc:
            app.logger.exception("failed to send %s alert", name)
            results[name] = {"error": str(exc)}

    return jsonify({"ok": True, "results": results})
