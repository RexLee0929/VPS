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
blue " Rex Lee's DDNS Script " 
blue " GitHub: https://github.com/RexLee0929 "
yellow " ========== DDNS Script ============ "
orange " 当前时间：$(date +"%Y-%m-%d %H:%M:%S") "

# 初始化默认参数
echo 
green " 初始化默认参数 " 
CFKEY="" # Cloudflare Global Key
CFUSER="" # Cloudflare 登录邮箱
CFZONE_NAME="" # 域名
CFRECORD_NAME="" # 解析 name 一定要包括域名，不然后续更新的时候会出错
CFRECORD_TYPE="A" # 选择记录的类型 A 或者 AAAA
CFTTL="1" # 选择 TTL 时间，默认 120 
FORCE="false"
CFPROXY="false" # 填入 true 或者 false 来控制是否启用代理
WANIPSITE="http://ipv4.icanhazip.com"

green " 正在解析参数 "
# 解析命令行参数
while getopts k:u:h:z:t:f:l:p: opts; do
  case ${opts} in
    k) CFKEY=${OPTARG} ;;
    u) CFUSER=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
    l) CFTTL=${OPTARG} ;;
    p) CFPROXY=${OPTARG} ;;
  esac
done

# 根据记录类型选择获取WAN IP的方式
if [ "$CFRECORD_TYPE" = "AAAA" ]; then
  WANIPSITE="http://ipv6.icanhazip.com"
fi

# 获取当前WAN IP
green " 获取当前 WAN IP "
WAN_IP=$(curl -s ${WANIPSITE})
blue " 当前 WAN IP : $WAN_IP "

# 定义WAN IP文件位置
WAN_IP_FILE=$HOME/.cf-wan_${CFRECORD_TYPE}_$CFRECORD_NAME.txt

# 获取Cloudflare Zone ID
green " 获取 Cloudflare Zone ID "
CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
  -H "X-Auth-Email: $CFUSER" \
  -H "X-Auth-Key: $CFKEY" \
  -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 ) || { echo " 获取 Zone ID 失败 "; exit 1; }
blue " CFZONE_ID: $CFZONE_ID"

# 获取DNS记录
green " 获取DNS记录 "
DNS_RECORDS_JSON=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?type=$CFRECORD_TYPE&name=$CFRECORD_NAME" \
  -H "X-Auth-Email: $CFUSER" \
  -H "X-Auth-Key: $CFKEY" \
  -H "Content-Type: application/json") || { echo " 获取DNS记录失败 "; exit 1; }
  
# 解析DNS记录的ID和内容（如果存在）
CFRECORD_ID=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="id":")[^"]*' | head -1) || { echo " 解析记录 ID 失败，可能是该记录不存在 "; }
EXISTING_IP=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="content":")[^"]*' | head -1) || { echo " 解析现有 IP 失败 "; }
EXISTING_PROXY=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="proxied":)[^,]*' | head -1) || { echo " 解析现有代理状态失败 "; }
EXISTING_TTL=$(echo $DNS_RECORDS_JSON | grep -Po '(?<="ttl":)[^,]*' | head -1) || { echo " 解析现有 TTL 失败 "; }

# 打印调试信息
echo 
# echo "Debug: Full API Response for DNS Records: $DNS_RECORDS_JSON"
blue " DNS 记录 ID = $CFRECORD_ID "
blue " DSN 记录 IP = $EXISTING_IP "
blue " DSN 代理 = $EXISTING_PROXY "
blue " DNS 记录 TTL = $EXISTING_TTL "

# 检查是否需要更新或创建记录
if [ -n "$CFRECORD_ID" ]; then
    green " 找到了记录，检查是否需要更新 "
    
    NEED_UPDATE=false
    
    # 检查IP
    if [ "$EXISTING_IP" != "$WAN_IP" ]; then
        NEED_UPDATE=true
    fi
    
    # 检查Proxy
    if [ "$EXISTING_PROXY" != "$CFPROXY" ]; then
        NEED_UPDATE=true
    fi
    
    # 检查TTL
    if [ "$EXISTING_TTL" != "$CFTTL" ] && [ "$CFPROXY" == "false" ]; then
        NEED_UPDATE=true
    fi
    
    if [ "$NEED_UPDATE" == "true" ]; then
        green " IP地址或代理状态或TTL有变化，正在更新 "
        
        # 如果Proxy为true，则强制设置TTL为1（Auto）
        if [ "$CFPROXY" == "true" ]; then
            CFTTL="1"
        fi

        # 更新记录
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
          -H "X-Auth-Email: $CFUSER" \
          -H "X-Auth-Key: $CFKEY" \
          -H "Content-Type: application/json" \
          --data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\", \"ttl\":$CFTTL, \"proxied\":$CFPROXY}")
        
        # 检查操作是否成功
        if [[ "$RESPONSE" == *'"success":true'* ]]; then
          orange " 更新记录成功! "
        else
          red ' 更新记录失败 : ( '
          red " Response : $RESPONSE " 
          exit 1
        fi
    else
        orange " IP 和 Proxy 状态没有变化，无需更新 "
    fi
else
    green " 没有找到记录，正在创建新记录 "
    # 创建记录
    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records" \
      -H "X-Auth-Email: $CFUSER" \
      -H "X-Auth-Key: $CFKEY" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\",\"ttl\":$CFTTL, \"proxied\":$CFPROXY}")
    
    # 检查操作是否成功
    if [[ "$RESPONSE" == *'"success":true'* ]]; then
      orange " 创建记录成功! "
    else
      red ' 创建记录失败 : ( '
      red " Response : $RESPONSE "
      exit 1
    fi
fi

echo
yellow " ========== DDNS Script ============ "
orange " 当前时间：$(date +"%Y-%m-%d %H:%M:%S") "
