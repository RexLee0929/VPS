#!/usr/bin/env bash

# 定义颜色函数
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
orange(){
    echo -e "\033[38;5;208m\033[01m$1\033[0m"
}

# 开启严格模式
set -o errexit
set -o nounset
set -o pipefail

echo
blue " Rex Lee's DDNS Script " 
yellow " ========== DDNS Script ============ "
orange " 当前时间：$(date +"%Y-%m-%d %H:%M:%S") "

# 初始化默认参数
CFKEY="" # Cloudflare Global Key
cf_email="" # Cloudflare 登录邮箱
domain="" # 域名
prefix="" # 解析 name 一定要包括域名
ip="" # IP
type="A" # 记录类型 A 或者 AAAA
cf_proxy="false" # true 或者 false 控制是否启用代理

# 解析命令行参数
green " 正在解析参数 "
while getopts k:e:d:r:t:p:a: opts; do
  case ${opts} in
    k) cf_key=${OPTARG} ;;
    e) cf_email=${OPTARG} ;;
    d) domain=${OPTARG} ;;
    r) prefix=${OPTARG} ;;
    t) type=${OPTARG} ;;
    p) cf_proxy=${OPTARG} ;;
    a) ip=${OPTARG} ;;
  esac
done

# 如果没有通过命令行参数指定 IP，则根据记录类型获取  IP
if [ -z "$ip" ]; then
  if [ "$type" = "AAAA" ]; then
    IP=$(curl -6 -s ip.sb)
  else
    IP=$(curl -4 -s ip.sb)
  fi
else
  # 使用命令行参数指定的 IP
  IP=$ip
fi

green " 当前 IP : $IP "

# 获取Cloudflare Zone ID
CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
  -H "X-Auth-Email: $cf_email" \
  -H "X-Auth-Key: $cf_key" \
  -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 ) || { red " 获取 Cloudflare Zone ID 失败 "; exit 1; }
blue " Cloudflare Zone ID: $CFZONE_ID"

# 获取DNS记录
green " 获取DNS记录 "
DNS_RECORDS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?type=$type&name=$prefix" \
  -H "X-Auth-Email: $cf_email" \
  -H "X-Auth-Key: $cf_key" \
  -H "Content-Type: application/json") || { red " 获取DNS记录失败 "; exit 1; }

CFRECORD_ID=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="id":")[^"]*' | head -1) || { red " 解析记录 ID 失败，可能是该记录不存在 "; }
EXISTING_IP=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="content":")[^"]*' | head -1) || { red " 解析现有 DNS 记录 IP 失败 "; }

if [ -n "$CFRECORD_ID" ]; then
    green " 记录已经存在，进行更新操作 "
    # 打印旧的记录情况
    blue " 旧的 DNS 记录 IP: $EXISTING_IP "

    RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
      -H "X-Auth-Email: $cf_email" \
      -H "X-Auth-Key: $cf_key" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$type\",\"name\":\"$prefix\",\"content\":\"$IP\", \"proxied\":$cf_proxy}")

    if [[ "$RESPONSE" == *'"success":true'* ]]; then
      orange " 更新记录成功! "
    else
      red ' 更新记录失败 : ( '
      red " Response : $RESPONSE " 
      exit 1
    fi
else
    blue " 创建新的 DNS 记录 "
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records" \
      -H "X-Auth-Email: $cf_email" \
      -H "X-Auth-Key: $cf_key" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$type\",\"name\":\"$prefix\",\"content\":\"$IP\", \"proxied\":$cf_proxy}")

    if [[ "$RESPONSE" == *'"success":true'* ]]; then
      orange " 创建 DNS 记录成功! "
    else
      red ' 创建 DNS 记录失败 : ( '
      red " Response : $RESPONSE "
      exit 1
    fi
fi

echo
yellow " ========== DDNS Script ============ "
orange " 当前时间：$(date +"%Y-%m-%d %H:%M:%S") "
