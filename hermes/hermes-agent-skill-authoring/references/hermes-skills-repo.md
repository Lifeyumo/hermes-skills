# hermes-skills Repo Collaboration Guide

## Repository Information

- **Repo:** Lifeyumo/hermes-skills (private)
- **Collaborator:** IamAAOOAAOOAA (push access)
- **Author:** 小砚
- **Local path:** `~/.hermes/skills/`

## Canonical Directory Structure

```
hermes/          # Hermes Agent core
  - hermes-agent               # Hermes Agent configuration/setup
  - hermes-agent-skill-authoring # SKILL.md authoring guide
  - hermes-skills-repo         # This document

openclaw/        # OpenClaw gateway + WeCom integration
  - openclaw                   # Gateway, plugins, QR pairing, channels

skills/          # Third-party / tool integrations
  - airtable, google-workspace, linear, maps, nano-pdf
  - notion, ocr-and-documents, powerpoint, safe-deep-delete

webdev/          # Web development templates
  - cardshop                 # PHP 卡密商城
  - extract-frontend-ui-only # Frontend UI extraction

system/          # System utilities (duplicates archived)
  - safe-deep-delete (canonical in skills/)

devops/          # Ops / deployment
  - ssh-tunnel-proxy
  - nginx-reverse-proxy

workflows/       # Development & workflow guides
  - planning                 # Umbrella: plan + writing-plans
  - dev-workflow             # Umbrella: spike + TDD + code review + subagent
  - kanban/                  # Kanban orchestrator + worker
  - webhook-subscriptions
```

## Skill File Format

Each skill is a `SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: "One sentence description."
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [tag1, tag2]
    related_skills: [other-skill]
    added_by: 小砚
    date_added: 2026-05-04
---
```

## Skill Quality Standards

- Narrow, class-level skills with labeled subsections
- `references/` for session-specific detail
- `templates/` for starter files
- `scripts/` for re-runnable verification actions
- No API keys or credentials in skill content
