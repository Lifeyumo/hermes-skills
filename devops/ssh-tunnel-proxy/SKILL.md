---
name: ssh-tunnel-proxy
description: SSH SOCKS5 tunnel + redsocks 分流代理——国内IP直连、国外IP走香港/海外代理服务器。用于绕过国内服务器的跨境访问限制。
category: devops
added_by: 小砚
date_added: 2026-05-05
tags: [ssh, tunnel, socks5, redsocks, iptables, ipset, proxy, geo-route]
trigger: 用户要求为国内服务器配置跨境代理 / SSH tunnel proxy / 分流代理 / autossh 后台隧道 / dante outbound RST / SOCKS5 连接被重置
---

# SSH SOCKS5 Tunnel + Geo-Route Proxy

## 架构

```
AA服务器(175.178.122.111)           本地/香港服务器(103.118.245.190)
┌─────────────────────┐            ┌─────────────────┐
│ 需求：走本地出口     │            │ SOCKS5 :1080     │
│ 访问国外网站        │◄────────── │ (dante/python)  │
│                     │  SSH隧道   │ redsocks :10808 │
│ iptables分流        │  反向转发   │ 代理出口         │
│  - 国内IP → RETURN  │            │                 │
│  - 国外IP → :10808  │            └─────────────────┘
└─────────────────────┘
```

**链路**：AA SSH主动连接本地 → 建立反向隧道(-R) → AA访问本地1080端口 → 流量穿隧道 → 本地出口

> ⚠️ **方向关键**：本地SSH主动连AA（AA的22端口对外开），建立 `-R 1080:localhost:1080` 反向隧道，AA连接本地端口即走隧道出去。而不是 autossh -D（出口在AA，方向错误）。

## 前置条件

- **代理出口服务器**：22 端口对内网/公网开放，`PubkeyAuthentication yes`，公钥已在 `~/.ssh/authorized_keys`
- **国内服务器**：ubuntu 用户（sudo 免密），能 SSH 到代理出口

## 步骤

### 1. 生成 SSH 密钥对（在本地"代理出口"服务器操作）

```bash
ssh-keygen -t ed25519 -C "hermes-proxy-AAOOAAOOAA" -f /tmp/hermes_proxy_key -N ""
cat /tmp/hermes_proxy_key.pub  # → 加到代理出口服务器的 ~/.ssh/authorized_keys
```

- 公钥放到**代理出口服务器**（本例即本地香港服务器 103.118.245.190）
- 私钥传到**国内服务器**（AAOOAAOOAA，即 175.178.122.111）

### 2. 代理出口服务器开启 PubkeyAuthentication

```bash
sed -i 's/^PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

### 3. 私钥传到国内服务器

```bash
PRIVKEY=$(cat /tmp/hermes_proxy_key)
ssh ubuntu@AAOOAAOOAA "echo '$PRIVKEY' | sudo tee /root/.ssh/hermes_proxy_key && sudo chmod 600 /root/.ssh/hermes_proxy_key"
# 如果 ubuntu 无法读 root 的私钥（autossh 以 ubuntu 运行），复制到 ubuntu 可读位置：
ssh ubuntu@AAOOAAOOAA "sudo cp /root/.ssh/hermes_proxy_key /home/ubuntu/.ssh/hermes_proxy_key && sudo chown ubuntu:ubuntu /home/ubuntu/.ssh/hermes_proxy_key && chmod 600 /home/ubuntu/.ssh/hermes_proxy_key"
```

### 4. 国内服务器安装依赖

```bash
sudo apt-get install -y autossh redsocks iptables ipset
```

### 5. 配置 redsocks

`/etc/redsocks.conf`:
```
base {
    log_debug = off;
    log_info = off;
    log = "syslog:daemon";
    daemon = on;
    redirector = iptables;
}

redsocks {
    local_ip = 127.0.0.1;
    local_port = 10808;
    ip = 127.0.0.1;
    port = 1080;
    type = socks5;
}
```

> ⚠️ 注意：redsocks 不接受 `0`/`1` 布尔值，必须用 `on`/`off`。

### 6. 配置 autossh 服务（systemd）

> ⚠️ **autossh 方向选择**：需求是"AA通过本地出口"，必须用**反向隧道 `-R`**，不是 `-D`。
> - `-D 1080`（动态转发）：建立 SOCKS5 代理，**出口在 AA 自身**（不符合需求）
> - `-R 1080:localhost:1080`（远程转发）：隧道对端（本地）监听 1080 端口，AA 连接本地 1080 流量从本地出口

`/etc/systemd/system/autossh-tunnel.service`:
```ini
[Unit]
Description=AutoSSH reverse tunnel - AA through local SOCKS5 exit
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/autossh -M 0 \
    -o "ServerAliveInterval 30" \
    -o "ServerAliveCountMax 3" \
    -o "StrictHostKeyChecking=no" \
    -i /root/.ssh/hermes_proxy_key \
    -R 1080:localhost:1080 \
    -N ubuntu@AA服务器IP
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable autossh-tunnel
sudo systemctl start autossh-tunnel
```

> ⚠️ 私钥路径用 `/root/.ssh/hermes_proxy_key`（autossh 以 root 运行）；AA 服务器的 sshd_config 需设 `GatewayPorts yes` 允许接收外部连接。

### 7. 配置分流路由脚本

`/usr/local/bin/proxy-route.sh`:
```bash
#!/bin/bash
PROXY_PORT=1080
REDIR_PORT=10808
CHINA_CIDR="/tmp/china_cidr.txt"

# 下载中国IP段（APNIC）
curl -s --max-time 30 https://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest \
  | grep "apnic|CN|ipv4" | awk -F"|" '{print $4"/"32-log($5)/log(2)}' \
  | sed 's/\/32$//' > ${CHINA_CIDR}

# 创建ipset（nonchina = 非中国IP）
ipset -F nonchina 2>/dev/null || ipset create nonchina hash:net
while read cidr; do
  [ -n "$cidr" ] && ipset add nonchina $cidr 2>/dev/null
done < ${CHINA_CIDR}

# 清理旧iptables规则
iptables -t nat -F PROXY 2>/dev/null
iptables -t nat -X PROXY 2>/dev/null
iptables -t nat -N PROXY

# 非中国IP走代理（重定向到redsocks）
iptables -t nat -A PROXY -p tcp -m set --match-set nonchina dst -j REDIRECT --to-port ${REDIR_PORT}
# 中国IP直连
iptables -t nat -A PROXY -p tcp -j RETURN

# 插入OUTPUT链
iptables -t nat -I OUTPUT -p tcp -j PROXY

echo "完成: 中国IP直连, 国外IP走代理"
```

### 8. 设置开机自启

```bash
sudo systemctl enable proxy-route
```

## 验证

```bash
# GitHub 走代理（应该有响应）
curl -s --max-time 8 --socks5 127.0.0.1:1080 https://api.github.com -o /dev/null -w '%{http_code}'

# 国内网站直连
curl -s --max-time 5 https://www.baidu.com -o /dev/null -w '%{http_code}'

# 整体测试（看 iptables 规则）
iptables -t nat -L PROXY -n
```

## 实战记录（2026-05-05）

### 场景
用户在国外，需要通过 SOCKS5 代理访问国内服务器 47.109.71.3（McTextHub 材质包网站）。

### 部署结果
- **代理服务器**：47.109.71.3（阿里云），系统 CentOS/Alibaba Cloud
- **代理协议**：SOCKS5，监听 0.0.0.0:255，3proxy 配置式部署
- **出口**：该服务器本身（直连目标网站）

### 关键坑：Docker 环境的 iptables

47.109.71.3 运行 Docker，iptables DOCKER 链末尾是 `DROP ALL`，导致外部无法连接 SOCKS5 端口。

**诊断**：
```bash
iptables -L DOCKER -n --line-numbers
# Chain DOCKER 末尾有 DROP 0 -- 0.0.0.0/0 0.0.0.0/0
```

**修复**：
```bash
iptables -I DOCKER 1 -p tcp --dport 255 -j ACCEPT
```

> ⚠️ **注意**：`iptables -I DOCKER` 插入到 DROP 规则之前有效。Docker 重启后规则可能失效，需要重启后检查。

### SSH 隧道打通失败排查路径

用户原本想在 AAOOAAOOAA（175.178.122.111）上建 SSH tunnel 到本地（103.118.245.190），再从 tunnel 访问 47.109.71.3。

**症状**：`Connection closed by remote host`（远程主机 22 端口直接拒绝）

**排查步骤**：
1. `nc -zv 103.118.245.190 22` → 端口可通
2. `sshpass -p 'PASSWORD' ssh root@103.118.245.190` → pubkey 认证失败（authorized_keys 空）
3. `ssh -i /root/.ssh/hermes_proxy_key root@103.118.245.190` → authorized_keys 里没有对应公钥
4. `ssh-keygen -y -f /root/.ssh/hermes_proxy_key` → 拿到公钥，写入目标机的 authorized_keys

**教训**：autossh tunnel 需要双向配置——不只是本机有私钥，目标机的 authorized_keys 里也必须有对应的公钥。

### DNS 解析问题（systemd-resolved）

47.109.71.3 使用 `systemd-resolved`（127.0.0.53），无法解析内网/本地域名（如 www.mctexthub.com），导致 SOCKS5 出口流量 DNS 失败。

**表现**：通过代理访问 127.0.0.1:80 正常，但访问 www.mctexthub.com 超时。

**临时解决**：手动加 hosts：
```bash
echo "47.109.71.3 www.mctexthub.com" >> /etc/hosts
```

**完整解决**：配置 systemd-resolved 使用 8.8.8.8 或在本地域名服务器添加解析。
**临时解决**：手动加 hosts：
```bash
echo "47.109.71.3 www.mctexthub.com" >> /etc/hosts
```

## 关键坑：OpenVZ 容器出站 RST（2026-05-05）

**症状**：dante/Python SOCKS5 在本地监听正常，AA 能连接，但 dante 发起 outbound 连接时本地 eth0 直接发送 TCP RST，curl 报 `Unable to receive initial SOCKS5 response`（curl 97）。

**诊断方法**：
```bash
# 启动 SOCKS5 后台监听
danted -f /etc/danted.conf

# 后台抓 RST 包（15秒）
timeout 20 tcpdump -i any 'tcp[tcpflags] & tcp-rst != 0' -n 2>&1 &
sleep 1 && curl -s --max-time 3 -x socks5h://127.0.0.1:1080 https://httpbin.org/get

# 结果：RST 来自 eth0 Out，源 IP 10.0.2.5（docker 网桥）
# 15:59:44.598454 eth0  Out IP 10.0.2.5.39669 > 80.82.64.96.55328: Flags [R.], seq 0
```

**教训**：排查 SOCKS5 代理 outbound 问题时，第一步应该是 `tcpdump -i any 'tcp[tcpflags] & tcp-rst != 0'` 抓包确认 RST 来源（本地发的还是远端发的），而不是反复换工具。

**关键发现（2026-05-05）**：

1. **dante `internal` 绑定地址决定生死**：配置 `internal: 0.0.0.0 port = 1080` 时 outbound 被 RST；换成 `internal: 127.0.0.1 port = 1080` 后本地 curl 测试完全正常（origin: 103.118.245.190）。原因：0.0.0.0 触发 Docker 网桥路由走 10.0.2.5 出站，被 host 层防火墙 RST；127.0.0.1 仅本地环回，不走 eth0 出口。

2. **danted 正确后台启动方式**：不带 `&` 后台符，用 `danted -D -f /etc/danted.conf`（`-D` 即 daemon mode）。带 `&` 会导致终端挂住且进程容易失控。

3. **AA 端 SOCKS5 出口链路**：AA 通过 proxychains4 → 127.0.0.1:1080（autossh 隧道在 AA 侧的监听）→ 隧道 → 本地 127.0.0.1:1080（dante）→ 出口 IP 正确。

4. **proxychains4 配置位置**：`/etc/proxychains4.conf` 中 `[ProxyList]` 段落下才是生效配置，不是文件中的示例行。

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `kex_exchange_identification: Connection closed` + `Connection closed by remote host` + auth.log **无记录** | TCP 层拦截（hosts.deny / 云安全组 / 防火墙），连接在到达 sshd 前就被阻断 | 目标机检查 `/etc/hosts.deny`，云厂商控制台安全组，**不是 sshd_config 问题** |
| `kex_exchange_identification: Connection closed` + auth.log **有记录** | sshd 主动拒绝 pubkey，算法规格不匹配 | 目标机添加 `PubkeyAcceptedAlgorithms ssh-ed25519`，`systemctl restart sshd` |
| autossh 进程在运行但端口未监听 | SSH 子进程（实际建隧道的）立即退出，通常是认证失败 | `pstree -p <autossh_pid>` 确认是否有 ssh 子进程；`ssh -vvv` 手动测试看具体哪一步失败 |
| `Permission denied (publickey)` | authorized_keys 缺失或路径/权限错误 | 确认公钥在目标机 `~/.ssh/authorized_keys`，本机私钥 `chmod 600` |
|------|------|------|
| `Permission denied (publickey)` | 代理出口服务器 `PubkeyAuthentication no` | 改配置并 `systemctl restart sshd` |
| `Permission denied (publickey)` | 私钥放在 `/root/.ssh/` 但 autossh 以 ubuntu 运行 | 复制到 `/home/ubuntu/.ssh/` |
| redsocks `bind: Address already in use` | 之前已启动过 | `pgrep redsocks` 确认进程数 |
| redsocks 启动失败 `boolean is not parsed` | 用 `0`/`1` 而非 `on`/`off` | 改用 `on`/`off` |
| iptables `--set option deprecated` | ipset 语法用错 | 用 `--match-set` 而非 `--set` |
| Docker 环境外部无法连接 SOCKS5 端口 | DOCKER iptables 链末尾 DROP 规则 | `iptables -I DOCKER 1 -p tcp --dport 端口 -j ACCEPT`，Docker 重启后需重新执行 |
| `ssh -D` 后 SOCKS5 超时，ssh 进程 CPU 50%+ | autossh ssh 子进程异常（CPU 占用异常高，连接挂起） | `systemctl restart autossh-proxy` 重启后立即恢复，重启后立刻测试 |
| `-R` 反向隧道建立后 AA 无法连接本地 1080 | AA 服务器 sshd 未开启 `GatewayPorts yes`，隧道只绑定了 127.0.0.1:10800（本地环回，外部无法访问） | AA 服务器执行 `sed -i 's/^#GatewayPorts.*/GatewayPorts yes/' /etc/ssh/sshd_config && systemctl restart sshd`，验证 `ss -tlnp | grep 10800` 确认绑定 `0.0.0.0` |
| 反向隧道端口被占用 | 本地 autossh-proxy 旧进程未清理，`-R 1080:localhost:1080` 尝试在 AA 监听 1080 但被占 | `ps aux \| grep autossh \| grep -v grep` 确认旧进程；`pkill -9 autossh` 清理后再启动 |
| `Unable to receive initial SOCKS5 response` (curl 97) | dante 配置了 `internal: 0.0.0.0`，Docker 网桥出站被 host 层防火墙 RST | 改为 `internal: 127.0.0.1 port = 1080` |
| `Connection refused` on 1080 but danted is running | danted 未以 daemon 模式启动（`&` 后台符不保证进程存活） | `danted -D -f /etc/danted.conf`（`-D` 是 daemon flag） |
| AA 端 iptables 规则不生效，报 `Permission denied (nf_tables)` | OpenVZ 容器不支持 iptables/nf_tables，无法做系统级分流 | 改用 proxychains 按需分流（`proxychains4 <cmd>`），不做 iptables ipset 分流 |

## 支持文件

- `references/ikev2-vpn-setup.md` — strongSwan IKEv2 VPN 部署（手机自带VPN协议），含 pki bug 绕过、证书生成、配置文件、手机连接参数
- `references/3proxy-setup.md` — 3proxy 源码编译 + SOCKS5 出口部署（本skill出口服务器默认方案）
- `references/redsocks.conf` — 验证过的 redsocks 配置模板
- `references/autossh-tunnel.service` — systemd 服务模板
- `references/proxy-route.sh` — 分流路由脚本模板
- `references/socks5-proxy-debug.md` — dante / Python SOCKS5 代理排障、curl non-standard greeting 处理、zombie 进程清理
- `references/ssh-tunnel-debug-20260505.md` — SSH 隧道打通失败排查路径（2026-05-05 实测）
- `references/aa-proxy-setup-20260505.md` — AA 走本地代理出站，验证通过的完整配置（dante+autossh+proxychains，2026-05-05 实测）
- `references/proxy-latency-benchmarks.md` — GitHub/Google 代理链路延迟实测数据（直连 vs 代理对比）
- `references/clash-socks5-proxy-provider.md` — Clash proxy-providers 不支持 socks5 的正确配置方式

## 叠加场景：代理出口服务器同时跑 3proxy SOCKS5 + Mihomo

香港/海外代理出口服务器（103.118.245.190）可以同时：
1. 作为 AAOOAAOOAA 国内服务器的跨境隧道终点（autossh tunnel，端口 1080）
2. 作为用户本地 Clash 客户端的代理服务器（3proxy SOCKS5，端口 1080；或 Mihomo，端口 7890）

两者互不干扰，分属不同端口。验证：`ss -tlnp | grep -E '1080|7890'`

**本次实践**：方案①使用 3proxy SOCKS5（`/opt/3proxy/bin/socks -p1080 -i0.0.0.0 -d`），进程 PID 99859，外部 Clash 客户端直接连接 `socks5://103.118.245.190:1080`。测试：GitHub 200(0.22s)，百度 200(0.20s)。

### 快速部署 3proxy 到多台机器

避免每台都编译（apt-get install 极慢或超时）：
1. 在编译好的机器上：`cp /opt/3proxy/bin/socks /tmp/3proxy`
2. 跨机器传文件：`sshpass -p 'PASSWORD' scp /tmp/3proxy root@NEW_SERVER:/tmp/3proxy`
3. 远端执行：`chmod +x /tmp/3proxy && cp /tmp/3proxy /usr/local/bin/`

### 3proxy systemd 启动失败（容器环境）

某些 VPS 容器不允许写 `/var/run/`，导致 `Type=forking + PIDFile` 方式报 `Can't open PID file`。解决：放弃 systemd，直接用 `background=true` 启动进程，或 `Type=simple`（不用 PIDFile）。
