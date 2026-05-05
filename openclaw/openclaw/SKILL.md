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

---

## 一键部署工作流（Deploy）

> SSH 连接 → 换源（国内）→ apt update → 安装 curl → screen 后台运行安装脚本 → 检测初始化进程

### 收集（依次问）

1. 服务器 IP
2. 端口（默认 22）
3. 用户名
4. 密码
5. 系统版本（默认 Ubuntu 22.04）

### Step 1 — 连接验证

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "echo connected"
```
→ 失败 → 输出 "连接失败: $ip:$port 用户:$user"，退出

### Step 2 — 国内换源 + 更新

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "echo '$pass' | sudo -S bash -c 'cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF' && sudo apt update"
```
→ 失败 → 输出 "apt update 失败，报错:$error"，退出

### Step 3 — 国外直接更新

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "sudo apt update"
```
→ 失败 → 输出 "apt update 失败，报错:$error"，退出

### Step 4 — 安装 curl

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "sudo apt install -y curl"
```
→ 失败 → 输出 "curl 安装失败，报错:$error"，退出

### Step 5 — 启动安装脚本

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "screen -dmS openclaw_install bash -c 'curl -fsSL https://openclaw.ai/install.sh | bash; exec bash'"
```
→ 失败 → 输出 "screen 启动失败，报错:$error"，退出

### Step 6 — 检测初始化进程

轮询检测（间隔 5s，超时 120s）：
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "screen -ls | grep openclaw_install"
```
- 存在 → 输出 "✅ OpenClaw 安装完成，可以开始接入配置了"
- 超时 → 输出 "⚠ screen session 未检测到，请手动 screen -r openclaw_install 查看状态"

### Step 7 — 定位安装路径

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "which openclaw || find /home -name openclaw -type f 2>/dev/null | head -3"
```
确认 openclaw 路径（通常是 `~/.npm-global/bin/openclaw`）

### Step 8 — 写入 API 配置

**方式A（推荐）**：整写完整配置文件
```bash
# 备份原配置
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "test -f ~/.openclaw/openclaw.json && cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak"
# 写入完整配置
scp references/openclaw-full-config.json $user@$ip:~/.openclaw/openclaw.json
```

**方式B**：增量 patch
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "openclaw config patch --file - << 'EOF'
{
  models: {
    providers: {
      minimax: {
        baseUrl: 'http://guizhouyun.site:2177',
        apiKey: 'sk-V2tQN9hwGACMyTZ0Ed372855Bb6049B6A9FaA196A8D6E4Dd',
        api: 'openai-completions',
        models: [
          {
            id: 'MiniMax-M2.7',
            name: 'MiniMax-M2.7',
            baseUrl: 'http://guizhouyun.site:2177'
          }
        ]
      }
    }
  }
}
EOF"
```
→ 失败 → 检查 config 是否存在: `ls ~/.openclaw/`

### Step 9 — 安装 Gateway systemd service

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "openclaw gateway install"
```
→ 失败 → 输出 "gateway install 失败，报错:$error"，退出

### Step 10 — 修复 gateway.mode（关键）

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "openclaw config set gateway.mode local"
```
→ 必须，否则 gateway 启动失败（报错: existing config is missing gateway.mode）

### Step 11 — 启动 gateway service

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "systemctl --user daemon-reload && systemctl --user enable --now openclaw-gateway.service"
```
→ 失败 → 检查 journalctl: `systemctl --user status openclaw-gateway.service`

### Step 12 — 验证

```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "sleep 5 && systemctl --user status openclaw-gateway.service 2>&1 | head -10"
```
- active (running) → ✅ 完成
- failed → 检查日志: `journalctl --user -u openclaw-gateway.service -n 20`

### 关键路径备忘

- openclaw 路径: `~/.npm-global/bin/openclaw`
- openclaw 配置: `~/.openclaw/openclaw.json`
- gateway service: `~/.config/systemd/user/openclaw-gateway.service`
- gateway 端口: 18789
- systemd 控制: `systemctl --user start/restart/status openclaw-gateway.service`
- API 验证: `curl -X POST '<baseURL>/v1/chat/completions' -H 'Authorization: Bearer <key>' -H 'Content-Type: application/json' -d '{"model":"<model>","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'`

### 已知坑（Deploy）

1. **gateway.mode 缺失**: 安装后首次启动必失败，必须先 `openclaw config set gateway.mode local`
2. **systemd 需要 user session**: 用 `systemctl --user`（不是 `sudo systemctl`）
3. **host key 变化**: 服务器重装后需 `ssh-keygen -R <ip>` 清除旧记录
4. **完整配置重写优于 patch**: patch 可能遗漏根级字段，推荐完整配置文件 scp 覆盖
5. **重启 Gateway 验证**: 光改配置不重启不生效
6. **微信插件安装屏幕捕获**: screen 会话内二维码是 ASCII 乱码，用 `screen -S <session> -X hardcopy /tmp/qr.txt` 捕获，再 grep 提取链接
7. **微信二维码链接有时效**: 链接几分钟内有效，过期则 pkill 重启插件安装会话再拿新链接

### 部署完整配置模板

`references/openclaw-full-config.md` — 完整配置参考（含 gateway.mode、models.providers 正确结构）

### 微信插件安装屏幕捕获（补充）

`screen -X hardcopy` 捕获的屏幕内容是ASCII艺术二维码，正确提取链接：
```bash
screen -S weixin_install -X hardcopy /tmp/qr.txt
cat /tmp/qr.txt | grep -E 'liteapp.weixin.qq.com|qrcode=' | tail -1
```
链接在 `qrcode=` 后面就是可访问的绑定链接。

### 配置文件无效字段（必知）

**禁止包含以下字段**，写入会导致 `openclaw plugins install` 报错 "Invalid config" 并拒绝加载：
- ❌ `wizard` — 顶级字段，已废弃
- ❌ `auth.profiles.<profile>:apiKey` — 应放在 `models.providers.<provider>:apiKey` 层
- ❌ `auth.profiles.<profile>:mode` — 部分版本不支持

**正确放置 apiKey 的位置**：
```json5
{
  "models": {
    "providers": {
      "deepseek": {
        "apiKey": "sk-xxx",  // ← API Key 在这里
        "baseUrl": "https://api.deepseek.com",
        "api": "openai-completions"
      }
    }
  }
}
```

**若已写入无效字段，修复方法**：
```python
cfg.pop('wizard', None)
if 'auth' in cfg and 'profiles' in cfg['auth']:
    for k in cfg['auth']['profiles']:
        cfg['auth']['profiles'][k].pop('apiKey', None)
```

### 服务器优先级（必知）

- **"服务器"默认指本地（103.118.245.190）**，不是外部服务器
- 外部服务器需用全名/IP区分：McTextHub（47.109.71.3）、AAOOAAOOAA（175.178.122.111）

### 本地服务器微信接入架构

```
企业微信 → OpenClaw (Node.js) → Hermes Gateway (port 8642) → AI 模型
```

**OpenClaw** 负责消息协议转换（微信协议 ↔ Hermes ACP 协议）。
**Hermes Gateway** 负责 AI 对话，监听 8642 端口，接收 OpenClaw 转发。

关键配置：
- OpenClaw 的 `gateway.token` 必须与 Hermes 配置一致
- Hermes 的 `weixin.enabled: true` + `weixin.port: 8642` 开启微信通道
- `WEIXIN_HOME_CHANNEL` 是微信端 channel 标识

> 注意：本架构下 OpenClaw 和 Hermes 是**独立运行的两个进程**，通过 HTTP 内部通信。
