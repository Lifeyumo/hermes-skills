---
name: openclaw-deploy
description: OpenClaw 一键部署工作流 —— ssh 连接 → 换源(国内) → apt update → 安装 curl → screen 后台运行安装脚本 → 检测初始化进程
triggers: ["/部署 OpenClaw 国内", "/部署 OpenClaw 国外"]
vars:
  region: 国内|国外（从命令后缀提取）
  ip, port, user, pass, os_version: 用户依次提供
  ssh_opts: "-o StrictHostKeyChecking=no"
  screen_session: openclaw_install
---

## 收集（依次问）
1. 服务器 IP
2. 端口（默认 22）
3. 用户名
4. 密码
5. 系统版本（默认 Ubuntu 22.04）

## Step 1 — 连接验证
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "echo connected"
→ 失败 → 输出 "连接失败: $ip:$port 用户:$user"，退出

## Step 2 — 国内换源 + 更新
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
→ 失败 → 输出 "apt update 失败，报错:$error"，退出

## Step 3 — 国外直接更新
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "sudo apt update"
→ 失败 → 输出 "apt update 失败，报错:$error"，退出

## Step 4 — 安装 curl
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "sudo apt install -y curl"
→ 失败 → 输出 "curl 安装失败，报错:$error"，退出

## Step 5 — 启动安装脚本
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip \
  "screen -dmS openclaw_install bash -c 'curl -fsSL https://openclaw.ai/install.sh | bash; exec bash'"
→ 失败 → 输出 "screen 启动失败，报错:$error"，退出

## Step 6 — 检测初始化进程
轮询检测（间隔 5s，超时 120s）：
sshpass -p '$pass' ssh -o StrictHostKeyChecking=no -p $port $user@$ip "screen -ls | grep openclaw_install"
- 存在 → 输出 "✅ OpenClaw 安装完成，可以开始接入配置了"
- 超时 → 输出 "⚠ screen session 未检测到，请手动 screen -r openclaw_install 查看状态"

## 原则
报错即停，不自己发明方案
