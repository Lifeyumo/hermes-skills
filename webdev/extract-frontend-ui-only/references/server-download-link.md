# 服务器文件下载到本地的标准流程

## 场景
用户需要从服务器获取文件/目录，但文件较大或无法直接传输。

## 核心模式（三步走）

1. **打包到 /tmp**：在服务器上 `tar -czf /tmp/xxx.tar.gz -C /目录 .`
2. **托管下载**：复制到 nginx 根目录（`/www/minecraft-blog/`），通过网站域名直接下载
3. **清理**：用完删除 `rm /www/minecraft-blog/xxx.tar.gz`

## 操作流程

```bash
# 步骤1：打包
sshpass -p '$PASS' ssh root@$IP "tar -czf /tmp/backup.tar.gz -C /path ."
# 步骤2：复制到 nginx 根目录
sshpass -p '$PASS' ssh root@$IP "cp /tmp/backup.tar.gz /www/minecraft-blog/backup.tar.gz"
# 步骤3：告知用户下载链接（http://$IP/backup.tar.gz）
# 步骤4：用完删除
sshpass -p '$PASS' ssh root@$IP "rm /www/minecraft-blog/backup.tar.gz"
```

## 适用条件
- 文件在 100MB~500MB 左右
- 服务器已部署 nginx 且有可用的域名/IP
- 临时下载，不需要长期托管

## 不适用
- 超大文件（>1GB）→ 用 `scp` 直传或对象存储
- 敏感文件 → 临时链接加密码保护或用完立即删除
