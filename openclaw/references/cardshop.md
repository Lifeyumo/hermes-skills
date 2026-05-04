# 卡网商城参考文档

## 项目位置
`~/cardshop-php/` — 完整 PHP 卡网商城（支付+卡密发货）

## 技术栈
- 后端：PHP（原生，无框架）
- 前端：原生 HTML/JS（ajax 请求后端 API）
- 数据库：MySQL
- 支付：小渡易支付 V2（RSA256 签名）

## 文件结构
```
~/cardshop-php/
├── config.php      # 配置（数据库+支付参数）
├── class/DB.php    # 核心类（PDO数据库+RSA签名/验签）
├── api.php         # API（goods列表、create订单）
├── notify.php      # 支付回调（收通知→发卡密）
├── return.php      # 跳转页面（显示卡密）
├── index.html      # 商城首页
├── init.php        # 数据库初始化
├── schema.sql      # SQL建表脚本
└── deploy/
    └── nginx.conf  # Nginx配置参考
```

## 核心流程
```
用户选购商品 → POST /api.php?act=create → 创建pending订单 → 返回支付链接
                                              ↓
用户支付 → 支付平台回调 /notify.php → 验签 → 查订单 → 发卡密 → status=paid
                                              ↓
用户跳转 /return.php → 查订单status=paid → 显示卡密
```

## 关键设计：购买类型不传回回调
- 订单创建时存入 `orders.good_id`（日卡/月卡/永久卡）
- 回调时通过 `out_trade_no` 查库取出 `good_id`
- 再查 `cards.good_id` 匹配发卡
- 所有商品共用一个 `/notify` 地址

## 三种商品（初始化数据）
| id | 名称 | type |
|----|------|------|
| 1 | 日卡 | day |
| 2 | 月卡 | month |
| 3 | 永久卡 | permanent |

## 支付签名（RSA SHA256）
- 签名参数：除 sign/sign_type 外所有参数按 key 排序后拼接
- 签名算法：`OPENSSL_ALGO_SHA256`
- 商户私钥：用于生成 sign（发给平台）
- 平台公钥：用于验签（验证回调真实性）

## 部署步骤
```bash
# 1. 导入数据库
mysql -u root -p < schema.sql

# 2. 修改 config.php
#    - DB_* 数据库配置
#    - PAY_* 易支付配置（PID、私钥、公钥、回调URL）

# 3. 放网站目录
cp -r ~/cardshop-php /var/www/cardshop-php

# 4. 配置 Nginx + PHP-FPM（参考 deploy/nginx.conf）

# 5. 访问 http://domain/index.html
```

## 回调地址要求
- 必须外网可访问（localhost 不行）
- 测试阶段用内网穿透（ngrok/cpolar）
- 小渡后台配置：notify_url + return_url

## 易支付 vs 小渡易支付
| | 易支付(ezfpy) | 小渡(xiaodq) |
|--|--|--|
| 签名 | MD5 | RSA SHA256 |
| 难度 | 低 | 高 |
| 退款代付 | ❌ | ✅ |
| 接口版本 | V1 | V2 |
| 回调格式 | 同参数+sign | 同参数+sign(RSA) |
