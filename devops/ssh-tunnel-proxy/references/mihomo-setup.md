# Mihomo (Clash.Meta) 安装配置参考

## 场景
在香港/海外服务器部署 Mihomo，为本地 Clash 客户端提供代理出口。
与 `ssh-tunnel-proxy` 叠加时，香港服务器同时承载：
1. AAOOAAOOAA 国内服务器的出境隧道出口
2. 用户本地 Clash 客户端的代理端点（HTTP/SOCKS5:7890）

## 安装

```bash
# 下载 Mihomo（MetaCubeX 维护的 Clash.Meta 分支）
curl -L -o /tmp/mihomo.gz \
  https://github.com/MetaCubeX/mihomo/releases/download/v1.19.24/mihomo-linux-amd64-compatible-v1.19.24.gz
gunzip -f /tmp/mihomo.gz
chmod +x /tmp/mihomo
cp /tmp/mihomo /usr/local/bin/mihomo
mkdir -p /etc/mihomo /var/log/mihomo
```

## 最小配置 `/etc/mihomo/config.yaml`

```yaml
mixed-port: 7890          # HTTP+SOCKS5 合并端口
redir-port: 7892          # Linux REDIRECT 透明代理用（可选）
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:9090   # RESTful API（仅本地访问）

proxy-providers:
  subscription:
    type: http
    url: "订阅链接（Base64 编码的 vmess/trojan 节点）"
    interval: 3600
    path: ./proxy-providers/subscription.yaml
    health-check:
      enable: true
      interval: 300
      url: https://www.gstatic.com/generate_204

proxy-groups:
  - name: 🔀 Proxy
    type: url-test
    use:
      - subscription
    url: "https://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50

  - name: 🛫 节点
    type: select
    use:
      - subscription

rules:
  - GEOIP,CN,DIRECT
  - MATCH,🔀 Proxy
```

## systemd 服务

```ini
[Unit]
Description=Mihomo Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mihomo
```

## 验证

```bash
# 检查节点是否加载
curl -s http://127.0.0.1:9090/proxies | python3 -c "
import sys,json
d=json.load(sys.stdin)
for k,v in d.get('proxies',{}).items():
    if isinstance(v,dict): print(k, '->', v.get('name',''), v.get('now','---'))
"

# 测试代理连通性
curl -s --proxy http://127.0.0.1:7890 https://api.github.com -o /dev/null -w '%{http_code}'
```

## 暴露给客户端的地址（香港服务器 103.118.245.190）

| 类型 | 地址 |
|------|------|
| HTTP/SOCKS5 | `http://103.118.245.190:7890` |
| 订阅地址（Clash 客户端用） | `http://103.118.245.190:7890/providers/proxies` |

## 踩坑记录

- `mixed-port` 同时提供 HTTP 和 SOCKS5，Clash 客户端填 HTTP 地址即可
- `allow-lan: false` 时只能本地访问 API，外部无法连接 9090 端口（正确）
- 订阅链接一般是 Base64 编码的 vmess，可用 `echo "base64string" | base64 -d` 解码验证
- Mihomo RESTful API (`external-controller`) 默认仅监听 `127.0.0.1`，不暴露到外网
