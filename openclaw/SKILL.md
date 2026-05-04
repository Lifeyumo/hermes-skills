---
name: openclaw-deploy
description: OpenClaw 一键部署工作流 —— ssh 连接 → 换源(国内) → apt update → 安装 curl → screen 后台运行安装脚本 → 检测初始化进程
triggers: ["部署 OpenClaw 国内", "部署 OpenClaw 国外"]
vars:
  region: 国内|国外（从命令后缀提取）
  ip, port, user, pass, os_version: 用户依次提供
  ssh_opts: "-o StrictHostKeyChecking=no"
  screen_session: openclaw_install
metadata:
  hermes:
    tags: [openclaw, deploy, ssh, 国内, 国外]
    added_by: 小砚
    date_added: 2026-05-04
---

## 收集（依次问）
1. 服务器 IP
2. 端口（默认 22）
3. 用户名
4. 密码
5. 系统版本（默认 Ubuntu 22.04）

## Step 1 — 连接验证
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "echo connected"
→ 失败 → 输出 "连接失败: $ip:$port 用户:$user"，退出

## Step 2 — 国内换源 + 更新
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
→ 失败 → 输出 "apt update 失败，报错:$error"，退出

## Step 3 — 国外直接更新
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "sudo apt update"
→ 失败 → 输出 "apt update 失败，报错:$error"，退出

## Step 4 — 安装 curl
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "sudo apt install -y curl"
→ 失败 → 输出 "curl 安装失败，报错:$error"，退出

## Step 5 — 启动安装脚本
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "screen -dmS openclaw_install bash -c 'curl -fsSL https://openclaw.ai/install.sh | bash; exec bash'"
→ 失败 → 输出 "screen 启动失败，报错:$error"，退出

## Step 6 — 检测初始化进程
轮询检测（间隔 5s，超时 120s）：
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "screen -ls | grep openclaw_install"
- 存在 → 输出 "✅ OpenClaw 安装完成，可以开始接入配置了"
- 超时 → 输出 "⚠ screen session 未检测到，请手动 screen -r openclaw_install 查看状态"

## Step 7 — 定位安装路径
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "which openclaw || find /home -name openclaw -type f 2>/dev/null | head -3"
→ 确认 openclaw 路径（通常是 `~/.npm-global/bin/openclaw`）

## Step 8 — 写入 API 配置

**方式A（推荐）**：整写完整配置文件（避免拼贴缺失字段）
```
# 备份原配置（若存在）
sshpass ... "test -f ~/.openclaw/openclaw.json && cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak"

# 写入完整配置（示例，可直接套用模板 references/openclaw-full-config.json）
scp references/openclaw-full-config.json $user@$ip:~/.openclaw/openclaw.json
```

**方式B**：增量 patch（已知原配置结构时使用）
```
sshpass ... "openclaw config patch --file - << 'EOF'
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

## Step 9 — 安装 Gateway systemd service
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "openclaw gateway install"
→ 失败 → 输出 "gateway install 失败，报错:$error"，退出

## Step 10 — 修复 gateway.mode（关键）
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "openclaw config set gateway.mode local"
→ 必须，否则 gateway 启动失败（报错: existing config is missing gateway.mode）

## Step 11 — 启动 gateway service
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "systemctl --user daemon-reload && systemctl --user enable --now openclaw-gateway.service"
→ 失败 → 检查 journalctl: `systemctl --user status openclaw-gateway.service`

## Step 12 — 验证
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "sleep 5 && systemctl --user status openclaw-gateway.service 2>&1 | head -10"
- active (running) → ✅ 完成
- failed → 检查日志: `journalctl --user -u openclaw-gateway.service -n 20`

## 关键路径备忘
- openclaw 路径: `~/.npm-global/bin/openclaw`
- openclaw 配置: `~/.openclaw/openclaw.json`
- gateway service: `~/.config/systemd/user/openclaw-gateway.service`
- gateway 端口: 18789
- systemd 控制: `systemctl --user start/restart/status openclaw-gateway.service`
- API 验证(独立): `curl -X POST '<baseURL>/v1/chat/completions' -H 'Authorization: Bearer <key>' -H 'Content-Type: application/json' -d '{"model":"<model>","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'`

## 微信插件安装屏幕捕获
`screen -X hardcopy` 捕获的屏幕内容是ASCII艺术二维码，直接cat会看到乱码。正确提取链接的方法：
```bash
screen -S weixin_install -X hardcopy /tmp/qr.txt
cat /tmp/qr.txt | grep -E 'liteapp.weixin.qq.com|qrcode=' | tail -1
```
链接在 `qrcode=` 后面的就是可访问的绑定链接。

## 卡网商城
项目模板已生成在 `~/cardshop/`，详见 `references/cardshop.md`

## 配置文件无效字段（必知）
`npx -y @tencent-weixin/openclaw-weixin-cli@latest install` 可通过 SSH screen 会话执行：
1. `sshpass ... "screen -dmS weixin_install bash -c '...install command...'"` 启动
2. `screen -S weixin_install -X hardcopy /tmp/qr.txt` 捕获二维码/链接
3. 链接过期后可重新 `pkill -f openclaw-weixin-cli` 再起

**安装前必须先清理无效配置字段**，当前版本（2026.4.29）不支持以下字段，写入会导致插件安装失败：
- `wizard`（顶级字段）
- `auth.profiles.<name>:apiKey`（嵌套在 auth.profiles 内部）

## 配置文件无效字段（必知）
配置 openclaw.json 时，**禁止**包含以下字段，否则 `openclaw plugins install` 会报错 "Invalid config" 并拒绝加载：
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
  },
  "auth": {
    "profiles": {
      "deepseek:default": {
        "provider": "deepseek",
        "mode": "api_key"
        // ← 不要在这里放 apiKey
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

## 本地服务器微信接入架构

本地服务器（103.118.245.190）采用 OpenClaw + Hermes 双组件架构：

```
企业微信 → OpenClaw (Node.js) → Hermes Gateway (port 8642) → AI 模型
```

**OpenClaw** 负责消息协议转换（微信协议 ↔ Hermes ACP 协议），运行在 Docker 或直接装在宿主机。
**Hermes Gateway** 负责 AI 对话，监听 8642 端口，接收 OpenClaw 转发。

关键配置：
- OpenClaw 的 `gateway.token`（认证 token）必须与 Hermes 配置一致
- Hermes 的 `weixin.enabled: true` + `weixin.port: 8642` 开启微信通道
- `WEIXIN_HOME_CHANNEL` 是微信端 channel 标识

> 注意：本架构下 OpenClaw 和 Hermes 是**独立运行的两个进程**，通过 HTTP 内部通信。不是 All-in-One。

## 服务器优先级（必知）
- **"服务器"默认指本地（103.118.245.190）**，不是外部服务器
- 外部服务器需用全名/IP区分：McTextHub（47.109.71.3）、AAOOAAOOAA（175.178.122.111）
- 记忆中的服务器列表：本地、McTextHub、AAOOAAOOAA

## 当前可用服务器状态
| 名称 | IP | 系统 | OpenClaw | 微信插件 |
|------|----|----|----------|----------|
| 本地 | 103.118.245.190 | Docker | ❌ | ❌ |
| McTextHub | 47.109.71.3 | Ubuntu | ❌ | ❌ |
| AAOOAAOOAA | 175.178.122.111 | Ubuntu | ✅ v2026.4.29 | ✅ 已配 |

> 101.32.190.140 已弃用，不再使用。

## AAOOAAOOAA 服务器修复记录
- 症状：Gateway 陷入循环，controlUi 导致页面不断刷新
- 修复：重写完整配置文件（不 patch），关键修改：
  - `controlUi.enabled = false`（禁用网页交互，防止死循环）
  - 换用新 DeepSeek API Key
  - `gateway.mode = "local"`
- 操作：备份原配置 → 整写新配置 → `systemctl --user restart openclaw-gateway.service`
- 验证：无需验证，直接告知用户完成（用户要求）

## 已知坑
1. **gateway.mode 缺失**: `openclaw gateway install` 后首次启动必失败，必须先 `openclaw config set gateway.mode local`
2. **systemd 需要 user session**: 用 `systemctl --user`（不是 `sudo systemctl`）
3. **host key 变化**: 服务器重装系统后 SSH host key 会变，本地需先 `ssh-keygen -R <ip>` 清除旧记录
4. **密码认证被禁用**: 部分服务器默认禁用密码认证，改用密钥；安装前确认密码登录是否仍可用
5. **服务器状态被清**: `.openclaw` 目录不存在说明插件被卸载了，需要重新走完整安装流程
6. **openclaw 不在 PATH**: 安装后二进制在 `~/.npm-global/bin/openclaw`，用完整路径执行
7. **--model 参数绕过 Gateway 被拒**: `openclaw agent --local --model xxx` 会报 `provider/model overrides are not authorized`，应走 Gateway 路由不加 --local
8. **完整配置重写优于 patch**: patch 可能遗漏根级字段（如 `gateway.mode`、`meta.*`），推荐用完整配置文件 scp 覆盖
9. **API 独立验证法**: 配置写入前先 curl 直接测后端 API，确认 key+URL 可用再写入 OpenClaw 配置
10. **重启 Gateway 验证**: 写入配置后必须 `systemctl --user restart openclaw-gateway.service`，光改配置不重启不生效
11. **微信插件安装屏幕捕获**: screen 会话内二维码是 ASCII 乱码，用 `screen -S <session> -X hardcopy /tmp/qr.txt` 捕获屏幕文本，再 grep 提取 `liteapp.weixin.qq.com` 链接
12. **微信二维码链接有时效**: 链接几分钟内有效，过期则 pkill 重启插件安装会话再拿新链接

## 原则
报错即停，不自己发明方案

## 转授参考
`references/share-to-other-ai.md`

## 完整配置模板
`references/openclaw-full-config.json` — 复制到 `~/.openclaw/openclaw.json` 后替换 `REPLACE_WITH_ACTUAL_TOKEN`
