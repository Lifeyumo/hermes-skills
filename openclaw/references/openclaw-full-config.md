# OpenClaw 完整配置文件模板

## 最小可用配置（DeepSeek 示例）

```json
{
  "agents": {
    "defaults": {
      "workspace": "/home/ubuntu/.openclaw/workspace",
      "model": {
        "primary": "deepseek/deepseek-v4-flash"
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "password",
      "token": "REPLACE_WITH_TOKEN",
      "password": "REPLACE_WITH_PASSWORD"
    },
    "port": 18789,
    "bind": "lan",
    "tailscale": {
      "mode": "off"
    },
    "controlUi": {
      "enabled": false,
      "allowInsecureAuth": false
    }
  },
  "plugins": {
    "entries": {
      "deepseek": {
        "enabled": true
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "deepseek": {
        "baseUrl": "https://api.deepseek.com",
        "apiKey": "REPLACE_WITH_API_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "deepseek-v4-flash",
            "name": "DeepSeek V4 Flash",
            "reasoning": true,
            "contextWindow": 1000000,
            "maxTokens": 384000,
            "input": ["text"],
            "cost": {
              "input": 0.14,
              "output": 0.28,
              "cacheRead": 0.028,
              "cacheWrite": 0
            },
            "compat": {
              "supportsReasoningEffort": true,
              "supportsUsageInStreaming": true,
              "maxTokensField": "max_tokens"
            },
            "api": "openai-completions"
          }
        ]
      }
    }
  },
  "auth": {
    "profiles": {
      "deepseek:default": {
        "provider": "deepseek",
        "mode": "api_key"
      }
    }
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },
        "bootstrap-extra-files": { "enabled": true },
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    }
  },
  "meta": {
    "lastTouchedVersion": "2026.4.29",
    "lastTouchedAt": "2026-05-02T00:00:00.000Z"
  }
}
```

## 禁用控制台 UI 的关键字段

```json
"controlUi": {
  "enabled": false,
  "allowInsecureAuth": false
}
```

## 微信插件额外配置

```json
"channels": {
  "openclaw-weixin": {
    "channelConfigUpdatedAt": "2026-05-02T00:00:00.000Z"
  }
}
```

## 禁止出现的字段（2026.4.29 不支持）

| 字段 | 位置 | 原因 |
|------|------|------|
| `wizard` | 顶级 | 已废弃 |
| `wizard.enabled` | 顶级 | 同上 |
| `auth.profiles.*.apiKey` | auth.profiles.<profile> | 应放在 models.providers.<provider>.apiKey |
