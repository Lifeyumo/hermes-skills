# Clash / FClash proxy-providers 不支持 socks5

## 错误信息

```
parse proxy provider HKProxy error: unsupport vehicle type: socks5
```

## 原因

Clash meta（如 FClash、Clash Verge meta、Clash for Android meta）不支持 `proxy-providers` 下的 `socks5` 类型。只能用直接 `proxies` 列表。

## 正确写法

```yaml
port: 7890
socks-port: 7891
allow-lan: false
mode: rule
log-level: info

proxies:
  - name: 🇭🇰 香港节点
    type: socks5
    server: 103.118.245.190
    port: 1080
    skip-cert-verify: true

proxy-groups:
  - name: 🔀 代理选择
    type: select
    proxies:
      - 🇭🇰 香港节点

rules:
  - GEOIP,CN,DIRECT
  - MATCH,🔀 代理选择
```

## 错误写法（不要用）

```yaml
proxy-providers:
  HKProxy:
    type: socks5    # ❌ 不支持
    url: socks5://103.118.245.190:1080
```

## 交付

托管订阅文件：
```bash
# 用 Python 简易 HTTP 服务器托管
python3 -m http.server 8080 --directory /tmp
```

订阅链接：`http://<服务器IP>:8080/clash-verge-sub.yaml`
