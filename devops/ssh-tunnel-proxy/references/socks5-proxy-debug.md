# SOCKS5 代理排障（dante / Python / 本地出口）

## 本地 SOCKS5 代理两个可用方案

### 方案 A：dante-server

```bash
apt-get install -y dante-server
```

`/etc/danted.conf`：
```
internal 0.0.0.0 port = 1080
external 10.0.2.5
socksmethod none
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
logoutput /var/log/danted.log
```

启动：
```bash
/usr/sbin/danted -D -f /etc/danted.conf
ss -tlnp | grep 1080  # 确认 0.0.0.0:1080 监听
```

### 方案 B：Python 最简 SOCKS5（dante 失败时的备选）

`/usr/local/bin/socks5_simple.py`：
```python
#!/usr/bin/env python3
import socket, threading

def handler(c):
    try:
        # 跳过客户端 greeting（curl 发一个字节 \x00）
        c.recv(1)
        c.sendall(b'\x05\x00')  # SOCKS5 version + no auth
        hdr = c.recv(4)
        if len(hdr) < 4:
            c.close(); return
        atyp = hdr[3]
        if atyp == 1:  # IPv4
            addr = c.recv(4); port = c.recv(2)
        elif atyp == 3:  # Domain
            dlen = c.recv(1)[0]; addr = c.recv(dlen); port = c.recv(2)
        else:
            c.close(); return
        real = socket.create_connection((socket.inet_ntoa(addr) if atyp==1 else addr, int.from_bytes(port,'big')), timeout=10)
        c.sendall(b'\x05\x00\x00\x01' + socket.inet_aton('0.0.0.0') + b'\x00\x00')
        while True:
            d = c.recv(4096); 
            if not d: break
            real.sendall(d)
        while True:
            d = real.recv(4096)
            if not d: break
            c.sendall(d)
    except: pass
    finally:
        try: c.close()
        except: pass
        try: real.close()
        except: pass

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', 1080))
s.listen(50)
while True:
    t = threading.Thread(target=handler, args=(s.accept()[0],), daemon=True)
    t.start()
```

> ⚠️ curl 发 non-standard greeting（只有 1 byte `\x00`），标准 SOCKS5 服务器期望 `\x05\xNN`，需跳过 greeting 首字节再回应。

## OpenVZ 容器 dante outbound RST 根因（2026-05-05）

**症状**：dante 监听 0.0.0.0:1080 正常，curl 连接 127.0.0.1:1080 成功发送 greeting，但 recv(10) 返回空，curl 报 `(97) Unable to receive initial SOCKS5 response`。

**抓包诊断**：
```bash
# 启动 dante
danted -f /etc/danted.conf

# 后台抓 RST（15秒足够）
timeout 20 tcpdump -i any 'tcp[tcpflags] & tcp-rst != 0' -n &
sleep 1 && curl -s --max-time 3 -x socks5h://127.0.0.1:1080 https://httpbin.org/get
```

**关键结论**：RST 来自 `eth0 Out`，源 IP `10.0.2.5`（容器内网 IP），不是外部服务器发的。说明防火墙在出口层（容器 host）拦截。

**根因**：OpenVZ host 对 10.0.2.5 做出口白名单，只放行 22 端口，dante 监听 1080 但自己发起 outbound 时 host 直接 RST。

**解决方向**：不在本地发起 outbound，改用 autossh 反向隧道 `-R`，让 AA 发起 outbound（AA 的 IP 出站没有这个限制）。

## dante 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `Unable to receive initial SOCKS5 response` | dante 内部错误/子进程 zombie 堆积 | `pkill -9 danted; pkill -9 -f danted; sleep 1; /usr/sbin/danted -D -f /etc/danted.conf` |
| zombie 进程残留 | 每次测试 ctrl+c 中断后进程未清理 | `ps aux \| grep dante \| grep -v grep \| awk '{print $2}' \| xargs kill -9` |
| 端口未监听（进程存在） | external 绑定 IP 不存在/错误 | `ip a \| grep 10.0.2.5` 确认网卡IP；`ss -tlnp \| grep 1080` 确认监听状态 |
| 外部无法连接 | 云安全组未开放 1080 端口 | 控制台添加入方向规则 TCP 1080 |

## 验证命令

```bash
# 确认端口状态
ss -tlnp | grep -E '1080|10808'

# 本地 SOCKS5 测试
curl -s --max-time 5 --socks5 127.0.0.1:1080 https://httpbin.org/ip

# AA 服务器上测试（通过 SSH 隧道）
curl -s --max-time 5 --socks5 127.0.0.1:1080 https://api.github.com/zen

# redsocks 进程状态
ps aux | grep redsocks | grep -v grep
journalctl -u redsocks -n 20 --no-pager
```
