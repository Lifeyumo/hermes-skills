# QQ机器人服务器子域名代理配置

**服务器**: 175.178.122.111 (Ubuntu 22.04)
**域名**: aaooaaooaa.dpdns.org

## 端口映射

| 子域名 | 目标端口 | 服务 |
|--------|----------|------|
| napcat.aaooaaooaa.dpdns.org | 6099 | napcat (QQ机器人) |
| astrbot.aaooaaooaa.dpdns.org | 6185 | astrbot |
| koishi.aaooaaooaa.dpdns.org | 5140 | koishi (clever_torvalds) |

## 验证命令

```bash
# 本地健康检查
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:6099   # napcat
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:6185   # astrbot
curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5140   # koishi

# 远程域名检查
curl -s -o /dev/null -w '%{http_code}' http://napcat.aaooaaooaa.dpdns.org
curl -s -o /dev/null -w '%{http_code}' http://astrbot.aaooaaooaa.dpdns.org
curl -s -o /dev/null -w '%{http_code}' http://koishi.aaooaaooaa.dpdns.org
```

## 状态码说明
- `200` — 服务正常，直接返回内容
- `301/302` — 服务本身在做跳转（napcat/astrbot/koishi 后端行为），代理层没问题
- `400/404` — DNS 未生效或域名解析错误
