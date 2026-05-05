# OpenClaw 完整配置模板

## 标准完整配置

复制到 `~/.openclaw/openclaw.json` 后替换 `REPLACE_WITH_ACTUAL_TOKEN`。

```json5
{
  "meta": {
    "version": "1.0.0"
  },
  "models": {
    "providers": {
      "minimax": {
        "apiKey": "REPLACE_WITH_ACTUAL_KEY",
        "baseUrl": "https://api.minimax.chat",
        "api": "openai-completions",
        "models": [
          {
            "id": "MiniMax-M2.7",
            "name": "MiniMax-M2.7",
            "baseUrl": "https://api.minimax.chat"
          }
        ]
      },
      "deepseek": {
        "apiKey": "REPLACE_WITH_ACTUAL_KEY",
        "baseUrl": "https://api.deepseek.com",
        "api": "openai-completions",
        "models": [
          {
            "id": "deepseek-chat",
            "name": "DeepSeek Chat",
            "baseUrl": "https://api.deepseek.com"
          }
        ]
      }
    }
  },
  "auth": {
    "profiles": {
      "minimax:default": {
        "provider": "minimax",
        "mode": "api_key"
      },
      "deepseek:default": {
        "provider": "deepseek",
        "mode": "api_key"
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "REPLACE_WITH_ACTUAL_TOKEN"
    },
    "bind": "lan"
  },
  "channels": {
    "wecom": {
      "enabled": false
    }
  }
}
```

## 关键字段说明

| 字段 | 必须 | 说明 |
|------|------|------|
| `gateway.mode` | ✅ | 必须是 `"local"`，否则启动失败 |
| `gateway.auth.token` | ✅ | 随机 token，用于 QR pairing |
| `gateway.auth.mode` | ✅ | 必须是 `"token"` |
| `gateway.bind` | 推荐 | `"lan"` 允许非本机连接 |
| `models.providers.*.apiKey` | ✅ | API Key 必须放在这里 |
| `auth.profiles.*:apiKey` | ❌ | 禁止放在这里，会导致插件安装失败 |
| `wizard` | ❌ | 禁止存在，已废弃 |

## AAOOAAOOAA 服务器实际配置

AAOOAAOOAA（175.178.122.111）的实际运行配置：

```json5
{
  "models": {
    "providers": {
      "deepseek": {
        "apiKey": "sk-...（已更新）",
        "baseUrl": "https://api.deepseek.com",
        "api": "openai-completions"
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "（已配置）"
    },
    "bind": "lan"
  },
  "controlUi": {
    "enabled": false
  }
}
```

> 注意：`controlUi.enabled = false` 用于防止 gateway 页面不断刷新的死循环问题。
