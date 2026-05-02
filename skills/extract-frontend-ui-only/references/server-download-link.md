# 服务器文件下载链接生成流程

## 适用场景
需要从云服务器拉取文件到本地，无需通过 scp/浏览器上传中转。

## 标准流程

1. **打包到 /tmp/**
   ```bash
   tar -czf /tmp/filename-$(date +%Y%m%d%H%M%S).tar.gz -C /源目录 . --exclude='排除项'
   ```

2. **复制到 nginx 根目录**（网站根目录已知为 `/www/minecraft-blog`）
   ```bash
   cp /tmp/filename.tar.gz /www/minecraft-blog/filename.tar.gz
   ```

3. **验证可访问**
   ```bash
   curl -s -o /dev/null -w "%{http_code}" http://服务器IP/filename.tar.gz
   # 期望返回 200
   ```

4. **生成下载链接**
   直接给出：`http://服务器IP/filename.tar.gz`

5. **用完删除**
   ```bash
   rm /www/minecraft-blog/filename.tar.gz
   ```

## 关键约束
- 禁止在删除前遍历文件分析内容
- 禁止输出任何文件列表
- 下载完成后立即删除，避免暴露
- nginx 只监听了 80 端口，确保服务器防火墙/安全组开放了 80

## 服务器凭证
- IP: 47.109.71.3
- 用户: root
- 密码: @WbnzwlY112516lxx（已记录在 memory）
