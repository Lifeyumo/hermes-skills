---
name: vpn-ikev2-deploy
description: Deploy IKEv2/IPSec VPN on Ubuntu with strongSwan. Covers certificate-based and PSK modes, Android/StrongSwan client setup, and common pitfalls.
added_by: 小砚
date_added: 2026-05-05
category: devops
tags: [vpn, ipsec, ikev2, strongswan, network]
linked_files:
  - references/ikev2-psk-mac-mismatch.md
  - references/clash-proxy-provider-socks5.md
  - references/3proxy-http-proxy.md
---

# IKEv2/IPSec VPN 部署

## 适用场景
- 服务器：Ubuntu（本文用香港 103.118.245.190）
- 客户端：Android (StrongSwan) / iOS / Windows / macOS
- 推荐模式：**PSK（预共享密钥）**，免证书，体验好

## 两种模式对比

| 模式 | 优点 | 缺点 |
|------|------|------|
| 证书模式 | 双向认证，安全性高 | Android 需导证书，p12 导入常失败 |
| **PSK 模式** | **配置简单，手机扫码即可** | 共享密钥需保护好 |

> ⚠️ 优先选 PSK，除非有特殊安全要求。

## PSK 模式部署（推荐）

### 1. 安装 strongSwan

```bash
apt-get install -y strongswan strongswan-pki libcharon-extra-plugins
```

### 2. 生成预共享密钥

```bash
PSK=$(openssl rand -base64 32)
echo "$PSK"  # 保存此密钥
cat > /etc/ipsec.secrets << EOF
: PSK "$PSK"
EOF
chmod 600 /etc/ipsec.secrets
```

### 3. 编写连接配置

```bash
cat > /etc/ipsec.d/ikev2.conf << 'EOF'
conn ikev2-psk
    auto = add
    keyexchange = ikev2
    type = tunnel
    authby = secret
    ike = aes256-sha256-modp2048
    esp = aes256-sha256-modp2048
    left = %any
    leftauth = psk
    # leftid 禁止在 PSK 模式下设为服务器 IP，会导致 MAC mismatched 错误
    right = %any
    rightauth = psk
    rightsourceip = 10.8.0.0/24
    auto = add
    dpdaction = clear
EOF
```

### 认证方式配置（重要！）

> ⚠️ `authby = eap-mschapv2` 是**错误写法**，会导致 `bad value: authby=eap-mschapv2` 报错。正确方式：
> - 省略 `authby` 字段
> - 单独设置 `rightauth = eap-mschapv2`（EAP 模式）或 `rightauth = psk`（PSK 模式）

**EAP 用户名密码模式（正确写法）：**
```
conn ikev2-eap
    auto = add
    keyexchange = ikev2
    type = tunnel
    left = %any
    leftauth = psk
    leftid = 103.118.245.190
    right = %any
    rightauth = eap-mschapv2
    rightsourceip = 10.8.0.0/24
    rightdns = 8.8.8.8,8.8.4.4
    auto = add
    dpdaction = clear
    eap_identity = %any
```

**PSK 模式（推荐）：**
```
conn ikev2-psk
    auto = add
    keyexchange = ikev2
    type = tunnel
    authby = secret
    ike = aes256-sha256-modp2048
    esp = aes256-sha256-modp2048
    left = %any
    leftauth = psk
    right = %any
    rightauth = psk
    rightsourceip = 10.8.0.0/24
    auto = add
    dpdaction = clear
```

> ⚠️ `leftid` 在 PSK 模式下不要设置为服务器 IP，否则客户端连不上，报 `MAC mismatched`。

### 4. Android StrongSwan 连接失败排查

| 错误信息 | 原因 | 解决 |
|---------|------|------|
| `bad value: authby=eap-mschapv2` | `authby` 不支持 `eap-mschapv2` 值 | 删掉 `authby` 行，`rightauth = eap-mschapv2` 单独写 |
| `MAC mismatched` | PSK 模式下 `leftid` 设为服务器 IP | 删掉 `leftid` 或设为其他值 |
| `no matching peer config found` | 配置未加载 | `ipsec reload` 后重试 |
| p12 导入"密码错误" | Android StrongSwan 对 p12 兼容性差 | **直接换 PSK 模式**（证书模式在 Android 上体验极差） |

> ⚠️ **重要结论**：IKEv2 证书模式在 Android 上几乎不可用（p12 导入失败率高），PSK 模式也常因 `leftid` 和 `authby` 配置问题连不上。如果追求"手机扫码/输入密钥就能用"，**直接用 WireGuard**，不要用 IKEv2。

### 5. 配置 NAT 转发

```bash
# 开启 IP 转发
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -w net.ipv4.ip_forward=1

# iptables NAT（VPN 网段 10.8.0.0/24 流量走 eth0 出去）
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
```

### 5. 开放防火墙端口

```bash
iptables -I INPUT -p udp --dport 500 -j ACCEPT
iptables -I INPUT -p udp --dport 4500 -j ACCEPT
iptables -I INPUT -p udp --dport 1701 -j ACCEPT
```

### 6. 启动服务

```bash
# 清理残留 PID 文件（重要！）
rm -f /var/run/starter.charon.pid /var/run/charon.pid
systemctl daemon-reload
systemctl enable strongswan-starter
systemctl restart strongswan-starter
```

### 7. 验证

```bash
ss -ulnp | grep -E "500|4500"
# 应看到 charon 监听 UDP 500/4500
```

## 证书模式部署（备选）

### 生成证书（用 openssl，不用 pki 工具）

```bash
mkdir -p /etc/ipsec.d/{cacerts,certs,private}
cd /etc/ipsec.d

# CA
openssl genrsa -out private/ca.key.pem 4096
openssl req -x509 -new -nodes -key private/ca.key.pem -sha256 \
  -days 3650 -out cacerts/ca.cert.pem \
  -subj "/CN=HK VPN CA"

# 服务器证书
openssl genrsa -out private/server.key.pem 4096
openssl req -new -key private/server.key.pem \
  -out certs/server.csr -subj "/CN=103.118.245.190"
openssl x509 -req -in certs/server.csr \
  -CA cacerts/ca.cert.pem -CAkey private/ca.key.pem \
  -CAcreateserial -days 365 -sha256 \
  -extfile <(printf "subjectAltName=IP:103.118.245.190\nextendedKeyUsage=serverAuth") \
  -out certs/server.cert.pem

# 客户端证书（给 p12 用）
openssl genrsa -out private/client.key.pem 4096
openssl req -new -key private/client.key.pem \
  -out certs/client.csr -subj "/CN=client"
openssl x509 -req -in certs/client.csr \
  -CA cacerts/ca.cert.pem -CAkey private/ca.key.pem \
  -CAcreateserial -days 365 -sha256 \
  -extfile <(printf "extendedKeyUsage=clientAuth") \
  -out certs/client.cert.pem

# 生成 p12（iOS/Android 用）
openssl pkcs12 -export \
  -in certs/client.cert.pem \
  -inkey private/client.key.pem \
  -certfile cacerts/ca.cert.pem \
  -name "HK VPN" \
  -passout pass:123456 \
  -out certs/client.p12

rm -f certs/*.csr
```

### 配置（证书模式）

```bash
cat > /etc/ipsec.d/ikev2.conf << 'EOF'
conn ikev2-cert
    auto = add
    compress = no
    type = tunnel
    keyexchange = ikev2
    forceencaps = yes
    ike = aes256-sha256-modp2048
    esp = aes256-sha256-modp2048
    fragmentation = yes
    left = %any
    leftauth = pubkey
    leftcert = server.cert.pem
    leftsendcert = always
    right = %any
    rightauth = pubkey
    rightauth2 = xauth
    rightsourceip = 10.8.0.0/24
    rightdns = 8.8.8.8,8.8.4.4
    auto = add
    dpdaction = clear
    dpddelay = 300s
    dpdtimeout = 1h
EOF

# 用户密码（可选，配合 xauth）
echo "username aes256-sha256 'password'" >> /etc/ipsec.secrets
```

## Android StrongSwan 客户端连接

### PSK 模式（推荐）
1. Google Play 装 **StrongSwan** App
2. 添加 VPN 配置 → 选「IKEv2/IPSec PSK」
3. 填写：
   - 服务器：`103.118.245.190`
   - IPSec 预共享密钥：`<生成的 PSK>`
   - **远程 ID**：`103.118.245.190`
   - **本地 ID**：（留空，不要填）
   - **用户名/密码**：（留空，PSK 模式不需要）
4. 保存 → 连接

> ⚠️ 部分 Android 客户端（如某些内置 IKEv2 的系统 VPN）不支持纯 PSK 模式，**必须用 StrongSwan App**。

### 证书模式（不推荐）
- p12 导入 Android 常失败 → 改用 PSK

## iOS 连接（证书模式）
1. Safari 下载 `vpn-client.p12`（密码 `123456`）和 `vpn-ca.crt`
2. 设置 → 通用 → VPN与设备管理 → 安装证书
3. 设置 → 通用 → 关于 → 证书信任设置 → 信任 CA
4. 添加 VPN 配置 → IKEv2 → 填服务器和用户名密码

## 常见问题

### Q: Android p12 证书导入显示密码错误？
**A:** p12 文件本身没问题（可用 `openssl pkcs12 -info -in client.p12 -passin pass:123456` 验证）。Android StrongSwan 对 p12 兼容性差，**直接换 PSK 模式**。

### Q: 服务启动后 UDP 端口没监听？
**A:** 检查是否有多个 charon 进程残留：
```bash
ps aux | grep charon | grep -v grep
# 杀残留进程，清理 PID 文件
rm -f /var/run/starter.charon.pid /var/run/charon.pid
systemctl restart strongswan-starter
```

### Q: 连接时显示 "no matching peer config found"？
**A:** 配置没加载。检查 `/etc/ipsec.d/ikev2.conf` 是否存在，`ipsec status` 是否能看到连接名。

### Q: 客户端连接后无法上网？
**A:** 检查 IP 转发和 NAT：
```bash
cat /proc/sys/net/ipv4/ip_forward  # 应为 1
iptables -t nat -L POSTROUTING -n | grep 10.8.0.0
```

## 交付物清单

| 文件 | 用途 |
|------|------|
| `/etc/ipsec.secrets` | PSK 或用户凭证 |
| `/etc/ipsec.d/ikev2.conf` | 连接配置 |
| `/etc/ipsec.d/cacerts/ca.cert.pem` | CA 证书（证书模式） |
| `/etc/ipsec.d/certs/client.p12` | 客户端证书（证书模式） |

## 交付信息模板（给用户）

```
服务器：<IP>
协议：IKEv2/IPSec PSK
预共享密钥：<PSK>
远程 ID：<服务器IP>
```

---

> 本 skill 覆盖 PSK 和证书两种部署方式。优先使用 PSK，证书模式仅作为备选记录。
