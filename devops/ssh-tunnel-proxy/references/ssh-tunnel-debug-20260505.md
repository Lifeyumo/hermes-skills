# SSH Tunnel 深度排障（2026-05-05）

## 问题现象

AAOOAAOOAA（175.178.122.111）上 autossh 进程存在（PID 46619），但 `ss -tlnp` 显示 1080 端口未监听，SSH 隧道未实际建立。

## 症状分析

```bash
# autossh 进程在运行
root 46619 /usr/lib/autossh/autossh -M 0 ... -D 0.0.0.0:1080 -N root@103.118.245.190

# 但端口未监听
$ sudo ss -tlnp | grep ':1080 '
# (无输出)

# curl 测试超时
$ curl -x socks5://175.178.122.111:1080 --connect-timeout 5 http://ip.sb
# (超时)

# SSH 直接连接失败
$ sudo ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/hermes_proxy_key \
    -D 1080 -N root@103.118.245.190
kex_exchange_identification: Connection closed by remote host
Connection closed by 103.118.245.190 port 22
```

## 关键发现

**Pubkey 本身有效**：
```bash
# 私钥对应的公钥
$ sudo ssh-keygen -y -f /home/ubuntu/.ssh/hermes_proxy_key
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5uirfpO2w7+vHpA1YguNYPHHTFdNK0nHZbyT8UnEz/ hermes-proxy-AAOOAAOOAA

# 目标机 authorized_keys 里有完全一致的公钥
$ sudo cat /root/.ssh/authorized_keys | grep hermes
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5uirfpO2w7+vHpA1YguNYPHHTFdNK0nHZbyT8UnEz/ hermes-proxy-AAOOAAOOAA
```

**但 pubkey 认证在 TCP 连接后立即被拒绝**——这说明问题不在 authorized_keys 配置，而在 SSH 协议层之前。

## 排查命令路径

```bash
# 1. 确认端口可达（TCP 三次握手）
nc -zv 103.118.245.190 22
# → Connection to 103.118.245.190 22 port [tcp/ssh] succeeded!

# 2. 详细 SSH 调试（看具体在哪一步失败）
sudo ssh -vvv -o StrictHostKeyChecking=no \
    -i /home/ubuntu/.ssh/hermes_proxy_key \
    -D 1080 -N root@103.118.245.190 2>&1 | tail -20

# 输出关键行：
# debug1: Connecting to 103.118.245.190 [103.118.245.190] port 22.
# debug1: Connection established.
# debug1: identity file ... type 3
# kex_exchange_identification: Connection closed by remote host

# 3. 确认 autossh 父进程存在
pstree -p 46619  # → autossh(46619)

# 4. 查看 autossh 的子 ssh 进程（隧道实际由子进程执行）
ps aux | grep 46619
# → 只看到 autossh 本身，看不到 ssh 子进程 → 子进程已退出

# 5. 用 lsof 查 autossh 进程的网络连接
sudo lsof -p 46619 2>/dev/null | grep -E 'TCP|IPv'

# 6. 查看目标机 sshd 日志（如有权限）
ssh ubuntu@175.178.122.111 "sudo tail -20 /var/log/auth.log | grep -i 'error\|refuse\|fail'"
```

## 可能原因（按优先级）

1. **`/etc/hosts.deny` 拦截**：`sshd: 175.178.122.111` 或 `ALL: 175.178.122.111` 直接拒绝 TCP 连接（auth.log 无记录）
2. **云厂商安全组/防火墙**：目标机 22 端口对来源 IP 有入向规则（TCP nc 成功不代表 SSH 协议层通）
3. **Fail2Ban / denyhosts**：自动封禁来源 IP，但封禁记录在 separate 日志
4. **TCP wrapper（tcpd）**：即使 sshd 配置正确，tcpd 也可以在握手前拒绝连接

## 已验证正常的反向路径

```bash
# 从 103.118.245.190 连接 AAOOAAOOAA 的 22 端口 → 正常
$ nc -zv 175.178.122.111 22
# → succeded

# 从 AAOOAAOOAA 连接 103.118.245.190 的 22 端口 → TCP 成功
$ nc -zv 103.118.245.190 22
# → succeded

# 但 SSH 协议层失败 → 排除纯网络层问题
```

## 结论（更新）

**auth.log 零记录 = 连接在到达 sshd 之前就被 TCP 层拦截**，不是 sshd 配置问题。Pubkey 双向验证通过，但 TCP 可达 ≠ SSH 协议可达。

**最可能的原因**（按优先级）：
1. `/etc/hosts.deny` 里有限制（`sshd: 175.178.122.111` 或 `ALL: 175.178.122.111`）
2. 云厂商安全组/防火墙（如阿里云安全组）对该 IP 出向 22 端口有规则
3. 目标机有 fail2ban/denyhosts 自动封禁

---

## 新发现（2026-05-05 下午）：autossh ssh 子进程异常 + 重启解决

### 问题现象

链路打通后一段时间（可能数小时后），autossh 的 ssh 子进程 CPU 占用异常高（50%+），SOCKS5 代理完全无响应（curl 超时，exit 28），但 autossh 父进程和 ssh 子进程都还在。

### 诊断路径

```bash
# 1. 检查 autossh ssh 进程 CPU
ps aux | grep '[a]utossh\|ssh.*-D' | head -5
# → ssh 子进程 CPU 50%+ 不正常（正常应该 <5%）

# 2. 确认端口还在监听
ss -tlnp | grep 1080
# → 端口监听正常，但连接挂起

# 3. 测试 SOCKS5 代理
curl -sI --max-time 10 -x socks5h://127.0.0.1:1080 https://httpbin.org/get
# → 超时，exit 28

# 4. 重启 autossh
systemctl restart autossh-proxy && sleep 3

# 5. 重启后立即测试
curl -sI --max-time 10 -x socks5h://127.0.0.1:1080 https://httpbin.org/get
# → HTTP/2 200，exit 0，恢复正常
```

### 根因

autossh 的 ssh 子进程在高负载或长连接状态下可能出现 CPU 异常高、连接挂起的情况，但父进程 autossh 认为 ssh 还在运行（端口监听正常），不会自动重启。**手动 `systemctl restart` 是唯一解决方法。**

### 预防建议

autossh 的 `-M 0` 禁用了内建监控，ssh 子进程异常不会触发自动重启。可考虑改用 `-M 20001`（ autossh 监控端口）让它自我修复。

### 快速验证脚本（链路节点测试）

```bash
#!/bin/bash
echo "=== 链路节点验证 ==="

# 节点1：autossh SOCKS5（本地 1080）
echo -n "[1] SOCKS5 1080 → "
curl -sI --max-time 5 -x socks5h://127.0.0.1:1080 https://httpbin.org/get | head -1
echo "exit: $?"

# 节点2：redsocks HTTP（本地 10808）
echo -n "[2] redsocks :10808 → "
curl -sI --max-time 5 -x http://127.0.0.1:10808 https://httpbin.org/get | head -1
echo "exit: $?"

# 节点3：AAOOAAOOAA 直连外网
echo -n "[3] AA 直连外网 → "
ssh -i /root/.ssh/id_rsa -o ConnectTimeout=5 ubuntu@175.178.122.111 \
  "curl -sI --max-time 5 https://httpbin.org/get" | head -1
echo "exit: $?"

# 节点4：autossh ssh 进程健康检查
echo "[4] autossh 进程 CPU:"
ps aux | grep '[s]sh.*-D' | awk '{print "    PID:"$2" CPU:"$3"% MEM:"$4"%"}'
```
