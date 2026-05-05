---
name: webui-bug-summary
description: "Hermes Web UI 搭建踩坑记录 — Git clone 超时、Provider 认证失败、QQ 会话不可见、官方 Dashboard 前端缺失。包含根因分析、修复方案和修复建议。"
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [hermes, web-ui, bug, troubleshooting, deployment, github-network, auth]
    added_by: Hermes Agent (AAOOAAOOAA 委托)
    date_added: 2026-05-04
---

# Hermes Web UI 搭建 Bug 总结

## 环境信息

- **OS**: Ubuntu 22.04 (jammy)
- **Python**: 3.11.15 (Hermes 运行环境) + 额外安装 3.10.12
- **Hermes Agent**: v0.12.0 (pip 安装版)
- **Web UI**: nesquena/hermes-webui v0.50.34 (第三方独立版，非官方 `hermes dashboard`)
- **平台**: QQ Bot（已配置运行中）

---

## Bug 1: Git Clone 超时（GitHub 国内访问问题）

**严重程度**: 🔴 阻塞性（无法下载源码就无法部署）

**现象**: 克隆 `github.com/nesquena/hermes-webui` 时反复超时。

```bash
# 尝试1：直接克隆 → 60s 超时
git clone -b v0.50.34 https://github.com/nesquena/hermes-webui.git
→ [Command timed out after 60s]

# 尝试2：加长时间 → 120s 仍然超时
git clone -b v0.50.34 https://github.com/nesquena/hermes-webui.git
→ [Command timed out after 120s]

# 尝试3：浅克隆（只拉最新commit）→ 180s 依然超时
git clone --depth 1 -b v0.50.34 https://github.com/nesquena/hermes-webui.git
→ Timeout (blocked)
```

**尝试过的方案及结果**:

| 方案 | 结果 | 分析 |
|------|------|------|
| 直接 clone + 增加超时（60s→120s→180s） | ❌ 均超时 | 非时间不够，是 TCP 连接被阻断 |
| `ghproxy.net` 国内镜像 | ❌ 同样超时 | ghproxy 在国内部分地区也不稳定 |
| `--depth 1` 浅克隆 | ❌ 超时 | 确认是网络层问题，非数据量问题 |
| **用户上传 zip 到 QQ** | ✅ 成功 | QQ 文件传输走国内 CDN，不受 GitHub 网络限制 |

**根因分析**:
1. **直接原因**: 服务器所在网络环境对 GitHub 的 TCP 连接不稳定（DNS 污染 / SNI 干扰 / 国际带宽限速）
2. **间接原因**: 仓库 `nesquena/hermes-webui` 体积较大（含测试文件、历史 commit），即使浅克隆也需要建立稳定的 TCP 连接
3. **环境因素**: 服务器位于中国内地，未配置 Git 代理或 hosts 优化

**最佳修复方案（推荐优先级排序）**:

```bash
# 方案 A（推荐）：配置 Git 代理（如果有代理）
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
git clone -b v0.50.34 https://github.com/nesquena/hermes-webui.git

# 方案 B：使用 Gitee 镜像（如果仓库有 Gitee 同步）
git clone -b v0.50.34 https://gitee.com/mirrors/hermes-webui.git

# 方案 C：修改 hosts 绕过 DNS 污染
echo "185.199.108.133 raw.githubusercontent.com" >> /etc/hosts
echo "185.199.109.133 github.com" >> /etc/hosts

# 方案 D（已验证有效）：手动上传 zip
# 用户从有网络的机器下载 zip，通过 QQ 文件传输发送到服务器
```

**经验教训**:
- QQ 文件传输是中国服务器获取 GitHub 源码的可靠 fallback 方案
- 对于大仓库，`--depth 1` 无法解决网络层面的阻断问题
- 系统中应提前配置 Git 代理或 mirrors，避免部署时卡住

---

## Bug 2: Web UI 显示 "Provider not authenticated"

**现象**: 登录 Web UI 后看到红色提示：
> "Provider 'deepseek' is configured but not yet authenticated."

**排查**:
- `config.yaml` 中已有 `providers.deepseek.api_key` ✅
- `auth.json` 中 `credential_pool.deepseek` 也有记录 ✅
- 但 `hermes auth status deepseek` 返回 `logged out`
- `.env` 文件中缺少 `DEEPSEEK_API_KEY` 环境变量 ❌

**原因**: DeepSeek 的 API Key 仅在 config.yaml 配置，未注册到 Hermes 认证系统。Web UI 的 onboarding 检测不到可用的 provider。

**解决**:
```bash
# 第1步：注册到认证系统
hermes auth add deepseek --type api-key --api-key sk-xxxx

# 第2步：补充环境变量到 .env
echo 'DEEPSEEK_API_KEY=sk-xxxx' >> ~/.hermes/.env

# 第3步：重启 Web UI
pkill -f "hermes-webui-0.50.34"
cd ~/hermes-webui-0.50.34 && bash start.sh
```

---

## Bug 3: Web UI 侧栏看不到 QQ 对话记录

**现象**: Web UI 左侧会话列表中只有 Web 自身的对话，QQ 上的对话不可见。

**排查**:
- `state.db` 中 QQ 会话数据完整 ✅
- Web UI 的 `get_cli_sessions()` 查询 `state.db` 时用了 `WHERE s.source != 'webui'`，理论上应包含 `qqbot` ✅
- **根本原因**: Web UI 设置 `show_cli_sessions: false` ❌

**解决**:
```bash
python3 -c "
import json
with open('/home/ubuntu/.hermes/webui/settings.json') as f:
    d = json.load(f)
d['show_cli_sessions'] = True
with open('/home/ubuntu/.hermes/webui/settings.json', 'w') as f:
    json.dump(d, f, indent=2)
"
```

**架构要点**:
- Web UI 的 `/api/sessions` 端点合并两类会话：
  1. **WebUI 本地会话** — `all_sessions()` 从 `~/.hermes/webui-mvp/sessions/` 读取
  2. **CLI/Agent 会话** — `get_cli_sessions()` 从 `~/.hermes/state.db` 读取
- 设置开关在 `settings.json` 的 `show_cli_sessions` 字段
- Gateway（QQ、Telegram等）的会话存储在 `state.db` 的 `sessions` 表中，`source` 字段标记平台名

---

## Bug 4: 官方 Dashboard 前端未构建

**现象**: `hermes dashboard` 命令可用，但 `web_dist/` 目录为空。

**原因**: 官方 dashboard 需要先构建 React 前端：
```bash
cd web/
npm install
npm run build
# 输出到 hermes_cli/web_dist/
```

当前环境未安装 Node.js 构建依赖，且用户选择的是第三方 `nesquena/hermes-webui`。

---

## 关键文件路径速查

| 文件 | 路径 |
|------|------|
| Web UI 配置 | `~/.hermes/webui/settings.json` |
| Hermes 配置 | `~/.hermes/config.yaml` |
| 环境变量 | `~/.hermes/.env` |
| 认证信息 | `~/.hermes/auth.json` |
| 会话数据库 | `~/.hermes/state.db` |
| Gateway 会话索引 | `~/.hermes/sessions/sessions.json` |
| Web UI 源码 | `~/hermes-webui-0.50.34/` |
| Web UI 日志 | `~/.hermes/webui/bootstrap-8787.log` |
