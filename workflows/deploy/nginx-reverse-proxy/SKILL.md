---
name: nginx-reverse-proxy
description: Nginx reverse proxy on Ubuntu — install, subdomains, SSL, firewall, verification
triggers:
  - nginx reverse proxy
  - nginx proxy pass
  - 子域名 反向代理
  - ubuntu nginx 配置
---

# Nginx Reverse Proxy

## Standard Workflow

### 1. 环境检查
```bash
# 目标服务器端口是否在监听
ss -tlnp | grep -E 'PORT'
# nginx 是否已安装
nginx -v
# 防火墙状态
ufw status
```

### 2. 安装 nginx
```bash
sudo apt-get update && sudo apt-get install -y nginx
```

### 3. 清理默认站点
```bash
sudo rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default
```

### 4. 放行端口
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 5. 编写 proxy 配置
```bash
sudo tee /etc/nginx/sites-available/YOUR_CONFIG << 'EOF'
server {
    listen 80;
    server_name SUBDOMAIN.YOUR_DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:TARGET_PORT;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_read_timeout 86400;
    }
}
EOF
```

### 6. 启用配置并重载
```bash
sudo ln -sf /etc/nginx/sites-available/YOUR_CONFIG /etc/nginx/sites-enabled/YOUR_CONFIG
sudo nginx -t && sudo systemctl reload nginx
```

### 7. 验证（本地 + 远程）
```bash
# 本地端口检查
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:TARGET_PORT

# 远程域名检查
curl -s -o /dev/null -w '%{http_code}' http://SUBDOMAIN.YOUR_DOMAIN
```

### 8. SSL（Let's Encrypt）
```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d SUBDOMAIN.YOUR_DOMAIN
```

## 参考资料
- [QQ机器人服务器子域名代理配置](./references/qq-robot-server-subdomains.md) — napcat/astrbot/koishi 三站代理实例

## 关键陷阱
- **用 `$host` 而非硬编码域名** — `$host` 保留原始 Host 头，避免后端服务无法识别来源
- **`nginx -t` 必须在重载前执行** — 语法错误会导致重载失败
- **`Upgrade` 和 `Connection 'upgrade'` 头** — WebSocket 服务必须加这两行，否则 ws 握手失败
- **`proxy_read_timeout 86400`** — 长连接/ws 应用需要，避免超时断连
- **确认 DNS 已生效** — 配完 nginx 后如域名解析未生效，curl 会报 400/404
- **先清理 default site** — Ubuntu 默认站点会抢 80 端口导致配置不生效
- **`try_files $uri` 被展开成 `/`** — 在 heredoc/SQL 拼接中写 nginx 配置时，`$uri` 变量会被本地 shell 展开为空导致变成 `try_files / =404`，所有路径都重定向到首页。**必须用 `\$uri` 转义**（heredoc 用单引号包裹 `EOF` 可阻止展开，但通过 `tee` 或 `cat >` 写文件时仍需手动转义）。验证方法：`grep try_files /etc/nginx/sites-available/YOUR_CONF`，确认输出是 `$uri` 而非 `/`
- **通过 SSH 写 nginx 配置的 heredoc 中 `$variable` 会被本地 shell 展开** — 所有 nginx 变量（`$uri`, `$host`, `$remote_addr` 等）在 heredoc 内容中必须写成 `\$variable` 或使用单引号 `EOF`（但 SSH 管道时单引号 EOF 仍可能在某些 ssh 版本中被本地展开）。安全做法：`ssh ... 'cat > /path/to/file' << 'REMOTE_EOF'\n...\nREMOTE_EOF`（注意 heredoc 放在 SSH 命令之外且用单引号包裹开始标记）
