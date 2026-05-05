#!/bin/bash
# 国内IP直连，国外IP走香港代理
# SOCKS5代理端口: 1080
# redsocks监听: 10808

PROXY_PORT=1080
REDIR_PORT=10808
CHINA_CIDR="/tmp/china_cidr.txt"

# 下载中国IP段（APNIC）
curl -s --max-time 30 https://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest \
  | grep "apnic|CN|ipv4" | awk -F"|" '{print $4"/"32-log($5)/log(2)}' \
  | sed 's/\/32$//' > ${CHINA_CIDR}

# 创建ipset（nonchina = 非中国IP）
ipset -F nonchina 2>/dev/null || ipset create nonchina hash:net
while read cidr; do
  [ -n "$cidr" ] && ipset add nonchina $cidr 2>/dev/null
done < ${CHINA_CIDR}

# 清理旧iptables规则
iptables -t nat -F PROXY 2>/dev/null
iptables -t nat -X PROXY 2>/dev/null
iptables -t nat -N PROXY

# 非中国IP走代理（重定向到redsocks）
iptables -t nat -A PROXY -p tcp -m set --match-set nonchina dst -j REDIRECT --to-port ${REDIR_PORT}
# 中国IP直连
iptables -t nat -A PROXY -p tcp -j RETURN

# 插入OUTPUT链
iptables -t nat -I OUTPUT -p tcp -j PROXY

echo "完成: 中国IP直连, 国外IP走香港代理"
