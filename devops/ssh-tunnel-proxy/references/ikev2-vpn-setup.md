# IKEv2 VPN 部署（strongSwan）

## 背景

用户手机不支持 SOCKS5，需要 IKEv2 协议。本出口服务器同时运行：
- 3proxy SOCKS5（端口 1080，给 Clash 客户端）
- strongSwan IKEv2（端口 500/4500，给手机自带 VPN）

## 环境

- 服务器：103.118.245.190
- 客户端 IP 池：10.8.0.0/24
- VPN 用户：vpnuser / vpnpass123
- p12 密码：123456

## 证书生成（openssl 替代 pki 工具）

> ⚠️ `pki --gen --type rsa` 在 strongSwan 5.9.5 有 bug（`building CRED_PRIVATE_KEY - RSA failed, tried 7 builders`），必须用 openssl 生成 RSA 密钥再转换。

```bash
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

# 客户端证书
openssl genrsa -out private/client.key.pem 4096
openssl req -new -key private/client.key.pem \
  -out certs/client.csr -subj "/CN=client"
openssl x509 -req -in certs/client.csr \
  -CA cacerts/ca.cert.pem -CAkey private/ca.key.pem \
  -CAcreateserial -days 365 -sha256 \
  -extfile <(printf "extendedKeyUsage=clientAuth") \
  -out certs/client.cert.pem

rm -f certs/*.csr private/*.srl

# 生成 p12（iOS/Android 需要）
openssl pkcs12 -export \
  -in certs/client.cert.pem \
  -inkey private/client.key.pem \
  -certfile cacerts/ca.cert.pem \
  -name "HK VPN" -passout pass:123456 \
  -out certs/client.p12
```

## 配置文件

### /etc/ipsec.conf
```
config setup
    charondebug = 0
    uniqueids = never

include /etc/ipsec.d/*.conf
```

### /etc/ipsec.d/ikev2.conf
```
conn ikev2-vpn
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
```

### /etc/ipsec.secrets
```
# 用户名密码认证
vpnuser aes256-sha256 'vpnpass123'
```

### /etc/strongswan.conf
```
charon {
    load_modular = yes
    plugins {
        include strongswan.d/charon/*.conf
    }
}
include strongswan.d/*.conf
```

## 部署步骤

```bash
# 安装
apt-get install -y strongswan strongswan-pki libcharon-extra-plugins

# 生成证书（用上面的 openssl 方法）

# 开启 IP 转发
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# iptables NAT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j MASQUERADE

# 启动
systemctl enable strongswan-starter
systemctl restart strongswan-starter
```

## 证书下载

通过 HTTP 服务（端口 8080）提供下载：
- CA：`http://103.118.245.190:8080/vpn-ca.crt`
- 客户端：`http://103.118.245.190:8080/vpn-client.p12`（密码：123456）

## iOS 连接参数

- 类型：IKEv2
- 服务器：103.118.245.190
- 账户：vpnuser
- 密码：vpnpass123
- 证书：导入 vpn-client.p12
- 信任 CA 证书

## 验证

```bash
systemctl status strongswan-starter
ipsec status
ss -tlnp | grep -E '500|4500'
```
