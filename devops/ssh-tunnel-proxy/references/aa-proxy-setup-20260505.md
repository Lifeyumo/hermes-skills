# AA 走本地代理出站 — 验证通过配置（2026-05-05）

## 完整链路

```
AA (175.178.122.111)
  └→ proxychains4 → 127.0.0.1:1080  (autossh 隧道在 AA 侧监听)
       └→ autossh 反向隧道 → 本地 (103.118.245.190)
            └→ danted (127.0.0.1:1080) → 出口 IP 103.118.245.190
```

## 本地配置

### danted /etc/danted.conf
```
logoutput: /var/log/danted.log
internal: 127.0.0.1 port = 1080
external: 10.0.2.5
method: none
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
```
启动：`danted -D -f /etc/danted.conf`
验证：`curl -x socks5h://127.0.0.1:1080 https://httpbin.org/get` → origin: 103.118.245.190

### autossh /etc/systemd/system/autossh-proxy.service
```ini
[Unit]
Description=AutoSSH reverse tunnel - expose local 1080 on AA
After=network.target

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 0 -N \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=3 \
    -o StrictHostKeyChecking=no \
    -R 0.0.0.0:1080:127.0.0.1:1080 \
    -i /root/.ssh/id_rsa \
    ubuntu@175.178.122.111
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## AA 配置

### AA sshd /etc/ssh/sshd_config
```
GatewayPorts yes
AllowTcpForwarding yes
```

### AA proxychains4 /etc/proxychains4.conf
```
[ProxyList]
socks5 127.0.0.1 1080
```
验证：`proxychains4 curl -s --max-time 5 https://httpbin.org/get` → origin: 103.118.245.190

### AA redsocks /etc/redsocks.conf
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
启动：`sudo systemctl start redsocks && sudo systemctl enable redsocks`

## 分流方案

OpenVZ 不支持 iptables/ipset，无法做系统级国内外分流。

**按需分流**：需要代理的命令前加 `proxychains4`，国内直连直接运行。
