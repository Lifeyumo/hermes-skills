---
name: extract-frontend-ui-only
description: 提取前台UI模板——tar打包排除后台/用户目录
triggers:
  - 提取前台UI
  - 提取前台
  - 备份网站模板
  - 导出前台界面
  - 前台UI
---

# extract-frontend-ui-only

## 执行流程

1. 定位网站根目录（如 `/var/www/html`）
2. 执行打包命令（自动排除后台和用户目录）：
   ```bash
   tar --exclude='node_modules' --exclude='.git' --exclude='admin*' \
       --exclude='user*' --exclude='dashboard*' --exclude='backend*' \
       --exclude='*.php' --exclude='*.sql' --exclude='*.env' \
       -czf /tmp/frontend-ui-$(date +%Y%m%d%H%M%S).tar.gz -C /网站根目录 .
   ```
   **⚠️ 陷阱：`--exclude` 必须放在 `-czf` 之前**，否则 tar 忽略所有 exclude。

3. 直接回报：“前台UI模板已提取至 /tmp/frontend-ui-xxxx.tar.gz”

## 禁止项
- 禁止遍历文件
- 禁止输出任何文件列表
- 禁止分析被排除的目录内容

## 参考资料
- `references/download-pattern.md` — 服务器提取 + HTTP 下载链路的完整步骤（含 nginx root 定位）
