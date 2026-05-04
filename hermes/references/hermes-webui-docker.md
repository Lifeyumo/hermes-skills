# Hermes WebUI Docker 部署参考

## 快速部署（单容器）

```bash
git clone https://github.com/nesquena/hermes-webui.git hermes-webui
cd hermes-webui
cp .env.docker.example .env
```

编辑 `.env`：

```
UID=0          # 容器内用户 UID（root 用 0）
GID=0          # 容器内用户 GID
HERMES_WEBUI_PASSWORD=your-secret-pass
HERMES_WEBUI_PORT=8787
```

启动：

```bash
docker compose up -d
```

健康检查：

```bash
curl http://127.0.0.1:8787/health
# {"status":"ok","sessions":0,"active_streams":0,"uptime_seconds":6.8}
```

## 关键点

- **镜像名**: `hermes-webui-hermes-webui`（docker compose 自动加项目名前缀），不是简单的 `hermes-webui`
- **UID=0**: 本地 root 用户(UID=0)，容器内也用 0，不匹配会导致 permission denied
- **127.0.0.1 绑定**: 默认只监听 localhost，外部访问需要 SSH 隧道
- **auto-discovery**: 容器自动检测 `~/.hermes/hermes-agent`，无需额外配置
- **首次启动**: 镜像构建需要 1-2 分钟（下载 Python slim + uv + 依赖）

## 外部访问（SSH 隧道）

服务器端默认只绑定 127.0.0.1，从本地机器隧道过去：
## 已知坑

1. **docker compose up -d 在 foreground 超时**: 必须用 `background=true` 参数运行
2. **health check 立即请求失败**: 容器创建后需要等 10-15 秒，等待 `docker ps` 显示 `Up N seconds (health: starting)`
3. **docker ps 显示空**: 说明容器没起来，看 `docker compose logs hermes-webui`
4. **容器内 UID/GID 持久化缓存**: docker_init.bash 在 `/tmp/hermeswebui_init/hermeswebui_user_uid` 缓存 UID，改 .env 后需要 `docker compose down`（不是 stop）彻底删除容器才能清除缓存
5. **WANTED_UID=0 仍以 1025 运行**: 容器内 hermeswebuitoo 用户无法通过 usermod 切换到 root（UID 0），导致绑定挂载的 `/root/.hermes` 和 `/usr/local/lib/hermes-agent` 无法访问
6. **AIAgent not available**: Docker 容器内 Python 环境（site-packages）与宿主机 Hermes venv 隔离，即使挂载了 hermes-agent 目录也找不到 run_agent 模块

## 推荐方案：宿主机 Python 直接运行

由于 Docker 容器权限和 Python 模块隔离问题复杂，推荐直接在宿主机跑 WebUI，与 Hermes 共用同一套 venv：

```bash
cd /root/hermes-webui
HERMES_WEBUI_AGENT_DIR=/usr/local/lib/hermes-agent \
HERMES_WEBUI_HOST=0.0.0.0 \
HERMES_WEBUI_PORT=8787 \
HERMES_WEBUI_PASSWORD=hermes123 \
HERMES_WEBUI_STATE_DIR=/root/.hermes/webui \
/usr/local/lib/hermes-agent/venv/bin/python server.py
```

后台运行（systemd 管理）：
```ini
[Unit]
Description=Hermes WebUI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/hermes-webui
ExecStart=/usr/local/lib/hermes-agent/venv/bin/python server.py
Environment="HERMES_WEBUI_AGENT_DIR=/usr/local/lib/hermes-agent"
Environment="HERMES_WEBUI_HOST=0.0.0.0"
Environment="HERMES_WEBUI_PORT=8787"
Environment="HERMES_WEBUI_PASSWORD=hermes123"
Environment="HERMES_WEBUI_STATE_DIR=/root/.hermes/webui"
Restart=always

[Install]
WantedBy=multi-user.target
```

关键环境变量：
- `HERMES_WEBUI_AGENT_DIR` — 必须指向宿主机 hermes-agent 路径（容器内为 `/home/hermeswebui/hermes-agent`）
- `HERMES_WEBUI_STATE_DIR` — 写到有权限的目录
- 密码必须设置，否则启动时警告"NO PASSWORD SET"

外部访问：`http://<服务器IP>:8787`，密码为 `HERMES_WEBUI_PASSWORD` 值。

## 外部访问（SSH 隧道）

服务器端默认只绑定 127.0.0.1，从本地机器隧道过去：

```bash
ssh -N -L 8787:127.0.0.1:8787 root@<服务器IP>
# 然后本地浏览器打开 http://localhost:8787
```

## 多容器方案

- `docker-compose.yml` — 单容器（默认，推荐）
- `docker-compose.two-container.yml` — Agent + WebUI 分离
- `docker-compose.three-container.yml` — Agent + Dashboard + WebUI

## 已知坑

1. **docker compose up -d 在 foreground 超时**: 必须用 `background=true` 参数运行
2. **health check 立即请求失败**: 容器创建后需要等 10-15 秒，等待 `docker ps` 显示 `Up N seconds (health: starting)`
3. **docker ps 显示空**: 说明容器没起来，看 `docker compose logs hermes-webui`
