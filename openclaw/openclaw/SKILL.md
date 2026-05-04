---
name: openclaw
description: "OpenClaw: gateway, plugins, QR pairing, channels (WeCom/企业微信, etc.), and node management."
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [openclaw, gateway, qr, pairing, wecom, clawbot, 企微]
    added_by: 小砚
    date_added: 2026-05-04
metadata:
  hermes:
    tags: [openclaw, gateway, qr, pairing, wecom, clawbot, 企微]
    related_skills: []
---

# OpenClaw

OpenClaw is a local AI gateway and orchestration platform. This skill covers gateway management, plugin lifecycle, QR pairing, and channel configuration.

## Hermes/OpenClaw 微信接入选择

### Hermes 原生微信接入（iLink，v0.12+）
Hermes 内置 Weixin / WeChat 支持（`hermes gateway setup` → 选项14）：
- 协议：腾讯 iLink（`ilinkai.weixin.qq.com`）
- 登录：二维码扫描（微信扫码授权）
- 凭证：`~/.hermes/.env`
- 限制：setup 是交互式 TUI，无法 SSH 管道驱动

**直接调 iLink API 获取二维码**（供外部工具）：
```bash
curl -s 'https://ilinkai.weixin.qq.com/ilink/bot/get_bot_qrcode?bot_type=3' \
  -H 'iLink-App-Id: bot' -H 'iLink-App-ClientVersion: 131074'
# → {"qrcode":"<hex>","qrcode_img_content":"https://liteapp.weixin.qq.com/q/<uuid>?qrcode=<hex>","ret":0}
```

### OpenClaw 微信接入（clawbot 平台）
如需更灵活的微信桥接（如企业微信、自建应用），通过 OpenClaw 的 clawbot 平台：

OpenClaw clawbot 平台环境变量：
```
WEIXIN_ACCOUNT_ID=<account_id>
WEIXIN_TOKEN=<token>
WEIXIN_BASE_URL=https://ilinkai.weixin.qq.com
```
写入 OpenClaw 环境变量配置（`~/.openclaw/.env` 或 systemd 环境文件），而非 Hermes。

## Gateway QR Code Generation

The `openclaw qr` command generates a mobile pairing QR code. It **fails silently with misleading errors** if prerequisites are missing.

### Prerequisites (must ALL be set)

```bash
# 1. Set gateway auth mode + generate a random token
openclaw config set gateway.auth.mode token
openclaw config set gateway.auth.token "$(openssl rand -hex 16)"

# 2. Allow non-loopback binding
openclaw config set gateway.bind lan
```

### Generate QR

```bash
# Full JSON output (setupCode is base64-encoded JSON with url + bootstrapToken)
openclaw qr --json

# Setup code only (for scripting)
openclaw qr --setup-code-only
```

### Decode setup code

```bash
echo "<setupCode>" | base64 -d
# Returns: {"url":"ws://...","bootstrapToken":"..."}
```

### Error: "Gateway auth is not configured"

→ `gateway.auth.token` is not set. Run the config set commands above.

### Error: "Gateway is only bound to loopback"

→ `gateway.bind` is not `lan`. Run `openclaw config set gateway.bind lan`.

### Restart gateway after config changes

```bash
openclaw gateway restart
```

## Plugin Management

### Install a plugin

```bash
openclaw plugins install <npm-spec>        # from npm registry
openclaw plugins install <name> --force    # reinstall if already present
```

### List installed plugins

```bash
openclaw plugins list
```

### Inspect a plugin

```bash
openclaw plugins inspect <plugin-id>
```

## WeCom Plugin (企业微信)

### Install WeCom plugin

```bash
openclaw plugins install @wecom/wecom-openclaw-plugin --force
```

### Webhook URL paths

| Mode | Path |
|------|------|
| Bot (recommended) | `/plugins/wecom/bot` |
| Agent | `/plugins/wecom/agent` |
| Legacy | `/wecom`, `/wecom/bot`, `/wecom/agent` |

Full webhook URL: `http://<server>:<port>/plugins/wecom/agent` (or `/bot`)

### WeCom Bot mode config

```bash
openclaw config set channels.wecom.enabled true
openclaw config set channels.wecom.connectionMode websocket  # default
openclaw config set channels.wecom.botId <BOT_ID>
openclaw config set channels.wecom.secret <BOT_SECRET>
```

### WeCom Agent mode config

```bash
openclaw config set channels.wecom.enabled true
openclaw config set channels.wecom.connectionMode webhook
openclaw config set channels.wecom.token <TOKEN>
openclaw config set channels.wecom.encodingAESKey <AES_KEY>
```

## Common Commands

```bash
openclaw status              # overview
openclaw status --all        # detailed
openclaw status --deep       # deep probe
openclaw logs --follow       # live logs
openclaw gateway restart     # restart gateway
openclaw channels list      # show channels
openclaw config get <path>   # read config value
openclaw config set <path>   # set config value
```

## Config file location

`~/.openclaw/openclaw.json`

## Node status

```bash
openclaw node status
```

The node service may run independently of the gateway service. Node service is often `systemd installed · enabled · running` while gateway runs in node-only mode (no local gateway process).

## Skill trigger

Load this skill when the user mentions openclaw, clawbot, wecom, 企业微信, QR pairing, or gateway pairing.

## References

- [clawbot-weixin.md](references/clawbot-weixin.md) — Clawbot/微信平台配置详情
