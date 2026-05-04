---
name: hermes-skills-repo
description: hermes-skills GitHub 仓库的协作管理 — 同步、分类、新增 skill 规范、与 AAOOAAOOAA 的协作流程
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [github, hermes-skills, repo, collaboration, 小砚]
    related_skills: [github-repo-management]
---

# hermes-skills 仓库协作规范

## 仓库信息
- 仓库：Lifeyumo/hermes-skills
- 可见性：private
- 协作者：IamAAOOAAOOAA（push 权限）
- 本地路径：~/.hermes/skills/

## Skill 分类结构

```
hermes/          # Hermes Agent 专属
  - hermes-deploy          # Hermes 部署安装
  - hermes-agent-skill-authoring  # skill 编写规范
openclaw/        # OpenClaw 接入
  - openclaw                 # gateway、插件、QR配对、渠道
  - openclaw-deploy          # 一键部署工作流
webdev/          # Web 开发
  - cardshop                 # PHP 卡密商城
  - extract-frontend-ui-only  # 提取前台 UI 模板
system/          # 系统工具
  - safe-deep-delete         # 安全深度删除
devops/          # 运维部署（保留现有）
  - kanban-orchestrator
  - kanban-worker
  - nginx-reverse-proxy
  - webhook-subscriptions
software-development/  # 软件开发（保留现有基础）
  - debugging-hermes-tui-commands
  - node-inspect-debugger
  - plan
  - python-debugpy
  - requesting-code-review
  - spike
  - subagent-driven-development
  - systematic-debugging
  - test-driven-development
  - writing-plans
```

## 新增 Skill 规范

新增 skill 时，SKILL.md 头部必须包含：

```yaml
---
name: <skill名>
description: "<一句话功能描述>"
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: []
    added_by: 小砚  # ← 必须标注
    date_added: 2026-05-04
---
```

## 与 AAOOAAOOAA 的协作流程

1. 每天北京时间 04:00 自动检查仓库动态 + 同步 main 分支
2. 如果 AAOOAAOOAA 新增分支，先报告给用户，等确认再同步
3. 用户询问仓库状态时，实时查询并报告：
   - 新增分支名称
   - AAOOAAOOAA 的 commit 内容
   - 开放 PR 状态

## 同步命令

```bash
cd ~/.hermes/skills
git remote -v  # 确认 origin
git pull origin main
```
