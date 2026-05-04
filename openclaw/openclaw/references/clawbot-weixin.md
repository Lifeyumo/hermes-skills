# Clawbot / 微信 (WeChat) 平台配置

## Clawbot 平台（ilinkai.weixin.qq.com）

Mac Mini 上使用的微信连接方案，通过 Clawbot 平台中转。

### 环境变量（写入 `~/.openclaw/.env` 或 systemd 环境文件）

```bash
WEIXIN_ACCOUNT_ID=ef68e664235a@im.bot
WEIXIN_TOKEN=ef68e6...353f
WEIXIN_BASE_URL=https://ilinkai.weixin.qq.com
```

### Hermes 的现状

- Hermes 的 `platform_toolsets` 支持的平台列表：**无 weixin**
- `channel_directory.json` 定义了 `weixin` 类型，但无对应 toolsets
- 桥接方案：通过 OpenClaw 的 clawbot 平台连接微信，Hermes 本身不支持微信通道

### 相关命令

```bash
openclaw status           # 查看状态
openclaw plugins list     # 已安装插件
openclaw qr --json        # 生成配对 QR 码
```
