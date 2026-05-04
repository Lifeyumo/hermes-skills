# 前台UI打包与下载：常用模式

## 服务器提取 + 本地下载链路

### 步骤1：定位网站根目录
```bash
sshpass -p '[密码]' ssh -o StrictHostKeyChecking=no root@[IP] "find /var/www /home /www -name 'index.html' 2>/dev/null | head -5"
```

### 步骤2：打包（exclude 放 -czf 前面）
```bash
sshpass -p '[密码]' ssh -o StrictHostKeyChecking=no root@[IP] \
  "tar --exclude='node_modules' --exclude='.git' --exclude='admin*' \
       --exclude='user*' --exclude='dashboard*' --exclude='backend*' \
       --exclude='*.php' --exclude='*.sql' --exclude='*.env' \
       -czf /tmp/frontend-ui-\$(date +%Y%m%d%H%M%S).tar.gz -C /www ."
```

### 步骤3：下载链接
将 tar.gz 放入 nginx 根目录即可通过 HTTP 下载：

**找 nginx root：**
```bash
# 查看 sites-enabled 中哪个是 default_server
cat /etc/nginx/sites-enabled/*
# 其中 server_name 含 47.109.71.3 或 xiaoyan666.xyz 且有 default_server 的是主站
# 其 root 即为 nginx 根目录
```

**本案已验证路径：**
- 网站根目录：`/www/minecraft-blog/`
- tar 放进去 → `http://47.109.71.3/frontend-ui.tar.gz` 直接可下载（Content-Type: application/gzip）

**常用模式：复制到 /www/minecraft-blog/ 下即可。**
