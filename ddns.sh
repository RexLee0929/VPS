#!/usr/bin/env bash

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
## 常规用绿色
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
## 标题用黄色
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
## 提示用蓝色
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
## 重要提示用橙色
orange(){
    echo -e "\033[38;5;208m\033[01m$1\033[0m"
}
    
# 开启严格模式
set -o errexit
set -o nounset
set -o pipefail

echo
yellow " === 开始运行DDNS更新脚本 === "

# 初始化默认参数
echo 
green " 初始化默认参数 " 
CFKEY=""# Cloudflare Global Key
CFUSER=""# Cloudflare 登录邮箱
CFZONE_NAME="yourdomain.com"# 域名
CFRECORD_NAME="hk.yourdomain.com"# 解析 name 一定要包括域名，不然后续更新的时候会出错
CFRECORD_TYPE=""# 选择记录的类型 A 或者 AAAA
CFTTL="120"# 选择 TTL 时间，默认 120 
FORCE="false"
CFPROXY="false"# 填入 true 或者 false 来控制是否启用代理
WANIPSITE="http://ipv4.icanhazip.com"

# 根据记录类型选择获取WAN IP的方式
if [ "$CFRECORD_TYPE" = "AAAA" ]; then
  WANIPSITE="http://ipv6.icanhazip.com"
fi

echo 
green " 正在解析参数 "
# 解析命令行参数
while getopts k:u:h:z:t:f:p: opts; do
  case ${opts} in
    k) CFKEY=${OPTARG} ;;
    u) CFUSER=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
    p) CFPROXY=${OPTARG} ;;
  esac
done

# 获取当前WAN IP
echo
green " 获取当前 WAN IP "
WAN_IP=$(curl -s ${WANIPSITE})
echo 
blue " 当前 WAN IP : $WAN_IP "

# 定义WAN IP文件位置
WAN_IP_FILE=$HOME/.cf-wan_${CFRECORD_TYPE}_$CFRECORD_NAME.txt

# 获取Cloudflare Zone ID
echo
green " 获取 Cloudflare Zone ID "
CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
  -H "X-Auth-Email: $CFUSER" \
  -H "X-Auth-Key: $CFKEY" \
  -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 ) || { echo "获取Zone ID失败"; exit 1; }
echo 
blue "CFZONE_ID: $CFZONE_ID"

# 获取DNS记录
echo 
green " 获取DNS记录 "
DNS_RECORDS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?type=$CFRECORD_TYPE&name=$CFRECORD_NAME" \
  -H "X-Auth-Email: $CFUSER" \
  -H "X-Auth-Key: $CFKEY" \
  -H "Content-Type: application/json") || { echo "获取DNS记录失败"; exit 1; }
  
# 解析DNS记录的ID和内容（如果存在）
CFRECORD_ID=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="id":")[^"]*' | head -1) || { echo "解析记录ID失败，可能是该记录不存在"; }
EXISTING_IP=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="content":")[^"]*' | head -1) || { echo "解析现有IP失败"; }
EXISTING_PROXY=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="proxied":)[^,]*' | head -1) || { echo "解析现有代理状态失败"; }

# 打印调试信息
# echo "Debug: Full API Response for DNS Records: $DNS_RECORDS_JSON"
echo 
blue " DNS 记录 ID = $CFRECORD_ID "
blue " DSN 记录 IP = $EXISTING_IP "
blue " DSN 记录代理状态 = $EXISTING_PROXY "

# 检查是否需要更新或创建记录
if [ -n "$CFRECORD_ID" ]; then
    echo
    green " 找到了记录，检查是否需要更新 "
    if [ "$EXISTING_IP" != "$WAN_IP" ] || [ "$EXISTING_PROXY" != "$CFPROXY" ]; then
        echo
        green " IP地址或代理状态有变化，正在更新 "
        # 更新记录
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
          -H "X-Auth-Email: $CFUSER" \
          -H "X-Auth-Key: $CFKEY" \
          -H "Content-Type: application/json" \
          --data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\", \"ttl\":$CFTTL, \"proxied\":$CFPROXY}")
        
        # 检查操作是否成功
        if [[ "$RESPONSE" == *'"success":true'* ]]; then
          echo 
          orange " 更新记录成功! "
        else
          echo 
          red ' 更新记录失败 : ( '
          red " Response : $RESPONSE " 
          exit 1
        fi
    else
        echo
        orange " IP 和 Proxy 状态没有变化，无需更新 "
    fi
else
    echo 
    green " 没有找到记录，正在创建新记录 "
    # 创建记录
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records" \
      -H "X-Auth-Email: $CFUSER" \
      -H "X-Auth-Key: $CFKEY" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\",\"ttl\":$CFTTL, \"proxied\":$CFPROXY}")
    
    # 检查操作是否成功
    if [[ "$RESPONSE" == *'"success":true'* ]]; then
      echo 
      orange " 创建记录成功! "
    else
      echo
      red ' 创建记录失败 : ( '
      red " Response : $RESPONSE "
      exit 1
    fi
fi

echo
yellow " === DDNS更新脚本运行完毕 === "
