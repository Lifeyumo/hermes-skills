---
name: openclaw-deploy
description: OpenClaw 一键部署工作流 —— ssh 连接 → 换源(国内) → apt update → 安装 curl → screen 后台运行安装脚本 → 检测初始化进程
triggers: ["/部署 OpenClaw"]
vars:
  region: 国内|国外（从命令后缀提取）
  ip, port, user, pass, os_version: 用户依次提供
  ssh_opts: "-o StrictHostKeyChecking=no"
  screen_session: openclaw_install
---

## 执行格式（用户口述版）
触发: /部署 OpenClaw {国内|国外}
收集: ip, port, user, pass, os_version
sshpass 连接验证
├─ 国内 → 写 sources.list (jammy) → apt update
├─ 国外 → apt update
└─ apt install -y curl

screen -dmS openclaw_install bash -c \
  'curl -fsSL https://openclaw.ai/install.sh | bash'

轮询 screen -ls + hardcopy 日志检测初始化完成
超时 120s，间隔 5s

完成 → "screen -r openclaw_install"

## 完整流程

### 1. 连接验证
```bash
sshpass -p '$pass' ssh $ssh_opts -p $port $user@$ip "echo connected"
```

### 2. 国内换源（Ubuntu jammy）
```bash
sshpass -p '$pass' ssh $ssh_opts -p $port $user@$ip "sudo bash -c 'cat > /etc/apt/sources.list << EOF
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

### 3. 国外只 apt update
```bash
sshpass -p '$pass' ssh $ssh_opts -p $port $user@$ip "sudo apt update"
```

### 4. 安装 curl
```bash
sshpass -p '$pass' ssh $ssh_opts -p $port $user@$ip "sudo apt install -y curl"
```

### 5. 后台运行安装脚本
```bash
sshpass -p '$pass' ssh $ssh_opts -p $port $user@$ip \
  "screen -dmS $screen_session bash -c 'curl -fsSL https://openclaw.ai/install.sh | bash; exec bash'"
```

### 6. 检测初始化进程
```bash
sshpass -p '$pass' ssh $ssh_opts -p $port $user@$ip \
  "screen -ls; sleep 3; screen -S $screen_session -X hardcopy /tmp/openclaw_screen.log 2>/dev/null; cat /tmp/openclaw_screen.log 2>/dev/null | grep -iE 'openclaw|init|welcome|setup|enter|press|next' | head -20"
```
轮询间隔 5s，超时 120s。

### 7. 完成提示
```
✅ OpenClaw 安装完成，初始化界面已启动。
screen -r openclaw_install
```

## 用户格式偏好
- 执行结果只报状态：✅/❌ + 一句话
- 不解释步骤，不输出过程描述
- 出错立即退出，不自己发明方案
