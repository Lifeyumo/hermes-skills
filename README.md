# hermes-skills

A curated collection of reusable skills for [Hermes Agent](https://hermes-agent.nousresearch.com) — documenting real-world workflows, deployment playbooks, and operational know-how accumulated from self-hosting.

> Hermes Agent 是一个 AI 助手框架，支持通过插件化 Skill 扩展功能。本仓库记录了在实际使用中积累的 Skill 与运维经验。

## 📂 Repository Structure

```
hermes-skills/
├── bugs/              # Bug records & root cause analysis
├── devops/            # Infrastructure & deployment playbooks
├── hermes/            # Hermes Agent config, web UI, debugging
├── openclaw/          # OpenClaw gateway & WeChat integration
├── system/            # System-level tools & utilities
├── webdev/            # Web development (cardshop, etc.)
└── workflows/         # Development workflows & best practices
```

## 🎯 What's Inside

| Category | Skills | Description |
|----------|--------|-------------|
| **devops** | 2 | SSH tunnel proxy, OpenClaw deployment |
| **hermes** | 3 | Dashboard, web UI, agent configuration |
| **openclaw** | 2 | OpenClaw setup, WeChat channel integration |
| **webdev** | 2 | Cardshop (卡密商城), frontend extraction |
| **workflows** | 6 | Nginx reverse proxy, kanban, code review, TDD, etc. |
| **bugs** | 1 | DeepSeek tool-calls error record |
| **system** | 1 | Safe deep deletion |

## 🚀 Quick Start

```bash
# Browse available skills
ls ~/.hermes/skills/

# View a specific skill
cat ~/.hermes/skills/devops/ssh-reverse-tunnel-proxy/SKILL.md
```

## 📝 Skill Format

Each skill is a `SKILL.md` file with YAML frontmatter:

```yaml
---
name: skill-name
description: One-line description
---

# Skill Title

## Problem
What problem does this solve?

## Solution
How to use it.

## Pitfalls
Known issues & edge cases.
```

## 🤝 Contributing

Contributions welcome! Please ensure:
- **No credentials or IP addresses** in any file (use `<PLACEHOLDER>` for sensitive values)
- Skills must have valid YAML frontmatter (`name` + `description` required)
- Include `Pitfalls` and `Verification Commands` sections

## ⚠️ Privacy Notice

This repository is **public**. Do NOT commit:
- Real server IPs or domain names
- API keys, tokens, or passwords
- User personal information

---

## 中文说明

本仓库是 ** hermes-skills** 的公开存档，记录了 Hermes Agent 的各类 Skill 与部署经验。

所有文件均已脱敏处理，不包含任何真实服务器地址或凭证信息。

如有问题或建议，欢迎提交 Issue / PR。
