# hermes-skills 仓库分类规则

> 本仓库由 **小砚** 创建维护，供 Hermes Agent 使用。
> 后续所有共维护者（开发者/AI 智能体）请遵循本规则。

---

## 一、顶级分类

本仓库有两类顶级节点，**平等独立，互不包含**：

| 分类 | 说明 |
|------|------|
| `skills/`（顶级目录） | 技能型 Skill，调用工具/功能完成特定任务 |
| `workflows/` | 工作流型 Skill，包含完整操作流程/步骤序列 |

**判断标准：**
- **Skill**：调用 Hermes 工具集（terminal/browser/file/...），完成某一类功能操作
- **Workflow**：包含多步骤操作流程，有明确先后顺序，通常需要跨多个工具完成一个完整场景

> **重要规则：Workflow 可以列入 Skill 分类，但 Skill 不能列入 Workflow。**
> 即：如果一个工作流专属于某个领域（如 OpenClaw 部署），应放入对应 Skill 分类目录下。

---

## 二、顶级目录结构

```
hermes/                  # Hermes Agent 专属
openclaw/                # OpenClaw 接入
webdev/                  # Web 开发专属
system/                  # 系统工具专属
workflows/               # 独立工作流（跨领域通用）
...（内置 skill 目录保留不动）
```

---

## 三、hermes/ — Hermes Agent 专属

**说明**：Hermes Agent 的部署、配置、技能编写相关。

| Skill | 描述 |
|-------|------|
| hermes-skills-repo | hermes-skills 仓库协作规范：同步、分类、新增 skill 规范 |
| hermes-deploy | Hermes Agent 一键部署：安装、配置、systemd 自启动 |
| hermes-agent | Hermes Agent 配置与操作 |
| hermes-agent-skill-authoring | Skill 编写规范与模板 |

| Dev Tool | 描述 |
|----------|------|
| debugging-hermes-tui-commands | Hermes TUI 斜杠命令调试 |
| node-inspect-debugger | Node.js 远程调试 |
| python-debugpy | Python 远程调试 |

---

## 四、openclaw/ — OpenClaw 接入

**说明**：OpenClaw 是连接 Hermes 与微信（企业微信）的桥接层。

| Skill | 描述 |
|-------|------|
| openclaw | OpenClaw gateway、插件、QR 配对、渠道配置 |
| openclaw-deploy | OpenClaw 一键部署：ssh → 换源 → 安装 → 启动 |

---

## 五、webdev/ — Web 开发

**说明**：小砚的 Web 开发相关项目。

| Skill | 描述 |
|-------|------|
| cardshop | PHP 卡密商城：项目结构、纯 PHP 渲染、数据库设计、易支付对接（V1/MD5 签名） |
| extract-frontend-ui-only | 提取前台 UI 模板：tar 打包排除后台/用户目录 |

---

## 六、system/ — 系统工具

**说明**：系统级工具，非业务向。

| Skill | 描述 |
|-------|------|
| safe-deep-delete | 安全深度删除：超大目录/文件的极速无遍历删除 |

---

## 七、workflows/ — 独立工作流

**说明**：跨领域通用工作流，不属于以上任意 Skill 分类时放入这里。

### workflows/deploy/ — 部署类

| Workflow | 描述 |
|----------|------|
| nginx-reverse-proxy | Nginx 反向代理一键部署：子域名、SSL 证书、自动续期 |

### workflows/plan/ — 计划类

| Workflow | 描述 |
|----------|------|
| plan | 写实施计划 |
| writing-plans | 规范化撰写计划文档 |

### workflows/dev/ — 开发调试类

| Workflow | 描述 |
|----------|------|
| spike | 调研类工作流：快速验证想法，输出结论 |
| systematic-debugging | 系统化调试流程：理解 → 定位 → 修复 → 验证 |
| test-driven-development | TDD 测试先行开发：红 → 绿 → 重构 |
| requesting-code-review | 发起代码审查：安全扫描、质量门禁、自动修复 |
| subagent-driven-development | 子 Agent 驱动开发：双层审查工作流 |

### workflows/kanban/ — 看板类

| Workflow | 描述 |
|----------|------|
| kanban-orchestrator | 任务看板编排：分解 playbook + 专员分工 |
| kanban-worker | 任务看板执行：pitfalls、边界情况处理 |

### workflows/ — 根目录

| Workflow | 描述 |
|----------|------|
| webhook-subscriptions | Webhook 订阅：事件驱动触发 Agent |

---

## 八、内置 Skill 目录（系统自带，不修改）

```
apple/                      # macOS 专用
autonomous-ai-agents/       # AI Agent 编排（claude-code、codex、opencode 等）
creative/                   # 创意内容（ASCII、图、设计、视频等）
data-science/               # 数据科学（Jupyter、数据分析）
diagramming/                # 图表绘制
dogfood/                    # QA 测试
domain/                     # 域名情报
email/                      # 邮件
gaming/                     # 游戏服务器
gifs/                       # GIF 搜索
github/                     # GitHub 工作流（auth、PR、issues、code review 等）
inference-sh/               # inference.sh 平台（150+ AI 应用）
mcp/                        # MCP 协议
media/                      # 媒体处理（YouTube、Spotify、MusicGen 等）
mlops/                      # 机器学习运维（训练、部署、量化、微调）
note-taking/                # 笔记（Obsidian）
red-teaming/               # 红队（jailbreak）
research/                   # 研究（arXiv、博客监控等）
smart-home/                 # 智能家居（飞利浦 Hue）
social-media/               # 社交媒体（X/Twitter、元宝）
yuanbao/                    # 元宝
```

---

## 九、添加规范

### 9.1 新增 Skill

1. 在对应分类目录下创建 `<skill-name>/SKILL.md`
2. 头部 frontmatter 必须包含：

```yaml
---
name: <skill-name>
description: <功能描述>
author: 小砚
date: 2026-05-04
---
```

3. 文件末尾添加变更记录：

```markdown
---

## 变更记录

| 日期 | 添加者 | 变更内容 |
|------|--------|---------|
| 2026-05-04 | 小砚 | 初始添加 |
```

### 9.2 新增 Workflow

同 Skill 规范，frontmatter 增加 `type: workflow`：

```yaml
---
name: <workflow-name>
description: <工作流描述>
type: workflow
author: 小砚
date: 2026-05-04
triggers:
  - <触发关键词1>
---
```

### 9.3 描述规范

每个 Skill/Workflow 的 `description` 必须包含：
- **功能**：做什么
- **触发条件**：什么情况下加载
- **边界**：明确不包含什么

---

## 十、分类争议处理

1. **优先**放入最相关的自定义分类（hermes/openclaw/webdev/system）
2. **无法归入**自定义分类时，放入 `workflows/` 对应子类
3. **仍然无法归类**：放入 `workflows/` 根目录，并在本 README 新增条目
4. **有争议时**：由小砚最终决定

---

## 十一、Git 协作规范

### 11.1 分支策略

| 分支 | 用途 |
|------|------|
| `main` | 主分支，稳定版本 |
| `<username>/<描述>` | 共维护者开发分支 |

### 11.2 Commit 规范

```
[<type>] <简短描述>

type: add | fix | refactor | docs | delete
```

### 11.3 同步流程

1. 共维护者创建新分支开发
2. 发起 PR
3. 小砚或授权 AI 审查合并
4. 合并后 main 自动同步到各 Hermes 实例

---

## 十二、变更记录

| 日期 | 添加者 | 变更内容 |
|--------|--------|---------|
| 2026-05-04 | 小砚 | 初始构建：重构目录结构，制定分类规范 |
