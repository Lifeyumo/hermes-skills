# 3proxy SOCKS5 编译安装（香港/海外出口服务器）

## 源码编译

```bash
cd /tmp
curl -fsSL https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.3.tar.gz -o 3proxy.tar.gz
tar xzf 3proxy.tar.gz
cd 3proxy-0.9.3
make -f Makefile.Linux
# 编译产物在 src/ 目录：socks, proxy, httpd 等
```

## 部署

```bash
sudo mkdir -p /opt/3proxy/bin
sudo cp /tmp/3proxy-0.9.3/src/socks /opt/3proxy/bin/socks
sudo chmod +x /opt/3proxy/bin/socks
```

## 启动（直接跑，不一定要 systemd）

```bash
/opt/3proxy/bin/socks -p1080 -i0.0.0.0 -d
```

参数说明：
- `-p1080` 监听端口
- `-i0.0.0.0` 监听地址（0.0.0.0 = 任意接口，对外暴露）
- `-d` daemonize（后台运行）

## systemd 服务（推荐持久化）

`/etc/systemd/system/3proxy-socks.service`:
```ini
[Unit]
Description=3proxy SOCKS5
After=network.target

[Service]
Type=forking
ExecStart=/opt/3proxy/bin/socks -p1080 -i0.0.0.0 -d
PIDFile=/var/run/3proxy-socks.pid

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable 3proxy-socks
sudo systemctl start 3proxy-socks
```

## 验证

```bash
# 本地测
curl -s --max-time 5 --socks5 127.0.0.1:1080 https://api.github.com -o /dev/null -w "本地: %{http_code} %{time_total}s\n"

# 外部测（从其他机器连）
curl -s --max-time 5 --socks5 103.118.245.190:1080 https://api.github.com -o /dev/null -w "远程: %{http_code} %{time_total}s\n"
```

## 为什么选 3proxy 而非 mihomo / shadowsocks

| 方案 | 适用场景 | 本次是否用 |
|------|---------|-----------|
| 3proxy | 轻量 SOCKS5/HTTP 代理出口，直连穿透 | ✅ 正确选择 |
| mihomo (Clash.Meta) | 订阅聚合+分流+规则，适合翻墙客户端 | ❌ 过度设计 |
| shadowsocks pip | Python 版，性能差，不推荐生产 | ❌ 已卸载 |
| gost | Go 版 SOCKS5，轻量简单 | 可选方案 |

## 已知问题

- **编译失败**：确保装了 `gcc make`
- **端口被占**：`lsof -i :1080` 查进程
- **外网连不上**：检查防火墙 `ufw allow 1080` / `iptables -I INPUT -p tcp --dport 1080 -j ACCEPT`
