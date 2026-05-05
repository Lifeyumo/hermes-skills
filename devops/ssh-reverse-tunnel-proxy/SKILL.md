---
name: ssh-reverse-tunnel-proxy
description: SSH 反向隧道全局代理方案——海外服务器通过 autossh 反向隧道 + danted 走国内出口加速访问 GitHub/Google
---

# SSH 反向隧道全局代理方案

## Problem
海外服务器访问 GitHub/Google 等国外网站延迟高（8s+），需要通过国内线路加速。

## Constraints
- 目标服务器（AA）无法 SSH 直连本地（端口不对外开放）
- OpenVZ 容器不支持 iptables/ipset，无法做系统级透明代理
- 只能通过环境变量 + proxychains 方案

## Solution
**链路**：AA → proxychains → autossh 反向隧道 → 本地 danted → 出口

### 架构
```
AA (175.178.122.111)
  └─ proxychains4 (socks5 127.0.0.1:1080)
       └─ redsocks (local_port 10808, relay 127.0.0.1:1080)
            └─ autossh 反向隧道 (-R)
                 └─ 本地 (103.118.245.190)
                      └─ danted (127.0.0.1:1080, external 10.0.2.5)
                           └─ 出口

国内网站：AA 直连
国外网站：AA → 隧道 → 本地出口
```

## 环境
| 角色 | IP | 说明 |
|------|----|------|
| 本地出口 | 103.118.245.190 | danted + autossh 客户端 |
| 海外服务器 | 175.178.122.111 | proxychains + redsocks |
| Dante 内网 | 10.0.2.5 | docker bridge 地址 |

## 步骤

### 第一阶段：本地（出口）配置

**1. 生成 SSH 密钥并复制到 AA**
```bash
ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""
ssh-copy-id -i /root/.ssh/id_rsa.pub ubuntu@<AA_IP>
```

**2. 安装并配置 danted**
```bash
apt install dante-server
```

`/etc/danted.conf`:
```
logoutput: syslog
internal: 127.0.0.1 port = 1080
external: 10.0.2.5
method: none
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
```

**3. 安装 autossh**
```bash
apt install autossh
```

**4. 配置 systemd 服务（autossh-proxy.service）**
```ini
[Unit]
Description=AutoSSH Reverse Tunnel Proxy
After=network.target

[Service]
Type=simple
User=root
Restart=always
RestartSec=10
Environment=AUTOSSH_GATETIME=0
ExecStartPre=/bin/sh -c 'ulimit -n 65535'
ExecStart=/usr/bin/autossh -M 0 -N -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" -o "StrictHostKeyChecking=no" -o "IdentityFile=/root/.ssh/id_rsa" -R 0.0.0.0:1080:127.0.0.1:1080 ubuntu@<AA_IP>

[Install]
WantedBy=multi-user.target
```

**5. 启动服务**
```bash
systemctl daemon-reload
systemctl enable autossh-proxy danted
systemctl start autossh-proxy danted
```

### 第二阶段：AA（海外服务器）配置

**1. 修改 SSH 配置**
```bash
sudo sed -i 's/#GatewayPorts.*/GatewayPorts yes/' /etc/ssh/sshd_config
sudo sed -i 's/#AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

**2. 安装 redsocks**
```bash
sudo apt install redsocks
```

`/etc/redsocks.conf`:
```
base {
    log_debug = off;
    log_info = off;
    daemon = on;
    user = redsocks;
    group = redsocks;
    log = "syslog";
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 10808;
    ip = 127.0.0.1;
    port = 1080;
    type = socks5;
}
```

**3. 安装 proxychains4**
```bash
sudo apt install proxychains4
```

`/etc/proxychains4.conf`:
```
[ProxyList]
socks5  127.0.0.1 1080
```

**4. 创建全局代理环境变量**
```bash
sudo tee /etc/profile.d/proxy.sh << 'EOF'
export http_proxy="socks5://127.0.0.1:1080"
export https_proxy="socks5://127.0.0.1:1080"
export HTTP_PROXY="socks5://127.0.0.1:1080"
export HTTPS_PROXY="socks5://127.0.0.1:1080"
export no_proxy="localhost,127.0.0.1"
export NO_PROXY="localhost,127.0.0.1"
EOF
sudo chmod +x /etc/profile.d/proxy.sh
source /etc/profile.d/proxy.sh
```

**5. 启动 redsocks**
```bash
sudo systemctl enable redsocks
sudo systemctl start redsocks
```

### 第三阶段：验证

**本地测试（隧道）**
```bash
curl -x socks5h://127.0.0.1:1080 https://httpbin.org/get
# 应返回 origin: <本地IP>
```

**AA 测试（代理链路）**
```bash
ssh ubuntu@<AA_IP> "source /etc/profile.d/proxy.sh && curl -s https://httpbin.org/get | grep origin"
# 应返回本地 IP

# GitHub 延迟对比
ssh ubuntu@<AA_IP> "time curl -s -o /dev/null https://github.com"
# 直连 vs 代理延迟差异巨大
```

## Pitfalls

1. **danted external 不能用公网 IP**：OpenVZ host 层对容器出站 IP 白名单限制，非 SSH 端口一律 RST。解决：用 docker bridge 内网 IP (10.0.2.5)，让 AA 侧的 autossh 隧道发起 outbound。

2. **autossh "Too many open files"**：ulimit -n 65535 写入 systemd service ExecStartPre。

3. **autossh 断线重连**：AUTOSSH_GATETIME=0 禁用首次连接超时检测，systemd Restart=always + RestartSec=10 自动重连。

4. **AA 重启后 autossh 重连失败**：AA sshd 需要完全启动后才能接受 autossh 连接。增加 ServerAliveInterval 30 和 ServerAliveCountMax 3 保持连接。

5. **环境变量对 git无效**：git 使用 `git config --global http.proxy socks5://127.0.0.1:1080` 单独配置。

6. **pip/npm 代理**：pip 支持 http_proxy/https_proxy；npm `npm config set proxy socks://127.0.0.1:1080`。

## Verification Commands

```bash
# 本地确认 autossh 隧道
ss -tlnp | grep 1080
systemctl status autossh-proxy

# AA 确认端口监听
ssh ubuntu@<AA_IP> "ss -tlnp | grep 1080"
ssh ubuntu@<AA_IP> "systemctl status redsocks"

# AA 验证代理出口
ssh ubuntu@<AA_IP> "source /etc/profile.d/proxy.sh && curl -s ifconfig.me"

# AA GitHub 延迟
ssh ubuntu@<AA_IP> "source /etc/profile.d/proxy.sh && time curl -s -o /dev/null https://github.com"
```

## Files Reference

| 文件 | 位置 | 用途 |
|------|------|------|
| danted.conf | 本地 | SOCKS5 代理服务 |
| autossh-proxy.service | 本地 | 反向隧道 systemd 服务 |
| redsocks.conf | AA | TCP->SOCKS5 转换 |
| proxy.sh | AA | 全局环境变量 |
| proxychains4.conf | AA | proxychains 配置 |

## Performance

| 场景 | 延迟 |
|------|------|
| AA 直连 GitHub | ~8.7s |
| AA 走代理 GitHub | ~0.7s |
| 本地直连 GitHub | ~1.2s |

---

*added_by: 小砚, date_added: 2026-05-05*
