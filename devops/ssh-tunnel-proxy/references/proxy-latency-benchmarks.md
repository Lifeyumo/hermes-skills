# 代理链路延迟实测（2026-05-05）

## 测试环境
| 角色 | IP | 说明 |
|------|----|------|
| 本地出口 | 103.118.245.190 | danted + autossh 客户端 |
| 海外服务器 | 175.178.122.111 | proxychains + redsocks |

## 实测数据

| 场景 | 延迟 |
|------|------|
| AA 直连 GitHub | ~8.7s |
| AA 走代理 GitHub | ~0.7s |
| 本地直连 GitHub | ~1.2s |
| AA 走代理 Google | ~0.9s |

**结论**：代理链路 GitHub 加速约 12 倍，延迟从 8.7s 降至 0.7s。

## 验证命令

```bash
# AA 直连 GitHub（慢）
ssh ubuntu@175.178.122.111 "time curl -s -o /dev/null https://github.com"

# AA 走代理 GitHub（快）
ssh ubuntu@175.178.122.111 "source /etc/profile.d/proxy.sh && time curl -s -o /dev/null https://github.com"

# AA 验证出口 IP
ssh ubuntu@175.178.122.111 "source /etc/profile.d/proxy.sh && curl -s ifconfig.me"
# 期望：103.118.245.190
```
