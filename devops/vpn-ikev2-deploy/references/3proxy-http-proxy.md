# 3proxy 同时提供 SOCKS5 和 HTTP 代理

## 背景

FClash 等 Clash meta 分支客户端在使用 SOCKS5 代理时可能不稳定，切换为 HTTP 代理后问题解决。

## 3proxy 正确配置

3proxy 的配置文件**不支持 `conf` 命令**（会报 `Unknown command: 'conf'`），直接用指令即可。

```bash
# /tmp/3proxy.cfg
nserver 8.8.8.8
nserver 8.8.4.4
auth none
socks -p1080 -i0.0.0.0
proxy -p1081 -i0.0.0.0
```

```bash
# 启动（后台运行）
pkill 3proxy 2>/dev/null
/opt/3proxy/bin/3proxy /tmp/3proxy.cfg &
```

## 两个端口

| 端口 | 协议 | Clash 配置写法 |
|------|------|---------------|
| 1080 | SOCKS5 | `type: socks5` |
| 1081 | HTTP | `type: http` |

## 验证

```bash
# SOCKS5
curl -s --proxy socks5://103.118.245.190:1080 https://www.google.com -o /dev/null -w "%{http_code}"

# HTTP
curl -s --proxy http://103.118.245.190:1081 https://www.google.com -o /dev/null -w "%{http_code}"
```

## Clash 订阅配置（HTTP 代理）

```yaml
proxies:
  - name: 🇭🇰 香港节点
    type: http
    server: 103.118.245.190
    port: 1081
    skip-cert-verify: true
```

## Systemd 服务（避免用 PID 文件）

容器环境下 PID 文件写入会报 `Operation not permitted`，使用 `Type=simple` 而非默认的 `Type=forking`。

```ini
[Unit]
Description=3proxy SOCKS5+HTTP Proxy
After=network.target

[Service]
Type=simple
ExecStart=/opt/3proxy/bin/3proxy /tmp/3proxy.cfg
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```
