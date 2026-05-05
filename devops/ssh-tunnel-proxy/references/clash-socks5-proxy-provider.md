# Clash Verge / FClash SOCKS5 节点配置

## 问题：proxy-providers 不支持 socks5

Clash 的 `proxy-providers` 支持 `http` 和 `file` 类型，**不支持 `socks5`**。

错误配置：
```yaml
proxy-providers:
  HKProxy:
    type: socks5        # ❌ 错误：unsupport vehicle type: socks5
    url: socks5://103.118.245.190:1080
```

## 正确做法：直接写 proxies

```yaml
proxies:
  - name: 🇭🇰 香港节点
    type: socks5                    # ✅ 直接定义
    server: 103.118.245.190
    port: 1080
    skip-cert-verify: true

proxy-groups:
  - name: 🔀 代理选择
    type: select
    proxies:
      - 🇭🇰 香港节点
```

## HTTP 代理写法（如果有）

```yaml
proxies:
  - name: 🇭🇰 香港节点
    type: http                      # ✅ HTTP 代理
    server: 103.118.245.190
    port: 1081
    skip-cert-verify: true
```

## Clash.meta / FClash 注意事项

- FClash 等第三方 Clash 客户端对 `proxy-providers` 兼容性更差
- 优先使用本地 `proxies` 定义，不要依赖 `proxy-providers`
- `proxy-providers` 只适合机场订阅聚合，不适合自建单节点
