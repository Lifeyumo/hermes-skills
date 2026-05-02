---
name: openclaw-deploy
description: OpenClaw 一键部署工作流 —— 通过 ssh 连接服务器，换源（如需）、安装、后台启动初始化界面
triggers: ["/部署 OpenClaw"]
---

# OpenClaw 一键部署工作流

## 触发词
`/部署 OpenClaw 国内` 或 `/部署 OpenClaw 国外`

## 变量
- `$region` — 国内/国外（从命令后缀提取）
- `$ip` — 服务器 IP
- `$port` — SSH 端口
- `$user` — 用户名
- `$pass` — 密码
- `$os_version` — 系统版本（如 Ubuntu 22.04）

## 流程

### Step 1 — 判断地区
从命令后缀提取 `$region`：`国内` 或 `国外`。

### Step 2 — 收集信息
依次询问（每次一条）：
1. 服务器 IP
2. 端口（默认 22）
3. 用户名
4. 密码
5. 系统版本（默认 Ubuntu 22.04）

### Step 3 — 连接服务器
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "echo connected"
```

### Step 4 — 国内换源 + 更新
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "echo '$pass' | sudo -S bash -c 'cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF' && sudo apt update"
```

### Step 5 — 国外直接更新
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "sudo apt update"
```

### Step 6 — 安装 curl
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "sudo apt install -y curl"
```

### Step 7 — 后台运行 OpenClaw 安装脚本（screen）
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "screen -dmS openclaw_install bash -c 'curl -fsSL https://openclaw.ai/install.sh | bash; exec bash'"
```

### Step 8 — 检测初始化进程
轮询检测 screen session `openclaw_install` 是否存在：
```bash
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "screen -ls; sleep 3; screen -S openclaw_install -X hardcopy /tmp/openclaw_screen.log 2>/dev/null; cat /tmp/openclaw_screen.log 2>/dev/null | grep -iE 'openclaw|init|welcome|setup|configuration|enter|press|next' | head -20"
```

轮询间隔：5秒，超时：120秒。

### Step 9 — 完成
检测到 OpenClaw 初始化界面后，返回：
```
✅ OpenClaw 安装完成，初始化界面已启动。
请在终端通过 screen 会话继续配置：
screen -r openclaw_install
```

## 注意事项
- 地区判断依据命令后缀（国内/国外），Step 2 询问时已知道地区，可跳过
- screen session 命名：`openclaw_install`，避免冲突
- 超时后若未检测到初始化界面，也返回提示并告知用户可手动 `screen -r openclaw_install` 查看
- 敏感信息（密码）不记录日志

## 验证步骤
- `sshpass ... "screen -ls"` 确认 session 存在
- `curl -fsSL https://openclaw.ai/install.sh | bash` 可先在本地测试网络连通性
