# IKEv2 PSK 模式调试笔记

## 问题：Android StrongSwan 连接失败 "MAC mismatched"

### 症状
Android StrongSwan 选「IKEv2/IPSec PSK」模式，填写服务器 IP + PSK 后连接失败。服务器日志：
```
tried 1 shared key for '103.118.245.190' - '103.118.245.190', but MAC mismatched
```

### 原因
`/etc/ipsec.d/ikev2.conf` 中 PSK 模式下设置了 `leftid = 103.118.245.190`，导致服务器用该 ID 计算 MAC，客户端发送的 AUTH 载荷验证不通过。

### 错误配置（不要用）
```bash
leftid = 103.118.245.190   # ❌ PSK 模式下不要设置 leftid 为服务器 IP
```

### 正确配置
```bash
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

### 验证命令
```bash
# 确认服务正常监听
ss -ulnp | grep -E "500|4500"

# 查看实时日志
journalctl -u strongswan-starter --no-pager -f

# 重启服务
rm -f /var/run/starter.charon.pid /var/run/charon.pid
ipsec restart
```

### PSK 生成
```bash
openssl rand -base64 16 | tr -d '/+='
```
