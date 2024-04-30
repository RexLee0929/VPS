#!/bin/bash

# 初始化变量
env_file="vps.env"
env_name="vps.env"
nnr_token=""
nnr_url=""
cf_key=""
cf_email=""
domain=""

# 使用getopts解析命名参数
while getopts "f:t:u:k:e:d:c:" opt; do
  case $opt in
    f) env_file="$OPTARG";;
    t) nnr_token="$OPTARG";;
    u) nnr_url="$OPTARG";;
    k) cf_key="$OPTARG";;
    e) cf_email="$OPTARG";;
    d) domain="$OPTARG";;
    c) choice="$OPTARG";;
    \?) echo "无效选项: -$OPTARG" >&2; exit 1;;
  esac
done

# 函数用于判断是否为URL
is_url() {
  if [[ $1 =~ ^https?:// ]]; then
    return 0  # 是URL
  else
    return 1  # 不是URL
  fi
}

# 根据env_file变量的值来决定操作
if is_url "$env_file"; then
  echo "从URL下载env文件：$env_file"
  curl -L "$env_file" -o "$env_name"
elif [ ! -f "$env_file" ]; then
  echo "未找到env文件。请输入文件地址以下载："
  read -r file_url
  if is_url "$file_url"; then
    curl -L "$file_url" -o "$env_name"
  else
    echo "提供的地址不是一个有效的URL。"
    exit 1
  fi
fi

# # 读取环境变量文件
# if [ -f "$env_file" ]; then
#   source "$env_file"
# else
#   echo "未找到环境变量文件：$env_file"
#   exit 1
# fi

# 读取环境变量文件
declare -A env_vars
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ $line =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*=.*$ ]]; then
    key="${line%%=*}"
    value="${line#*=}"
    # 删除可能的引号
    value="${value%\"}"
    value="${value#\"}"
    env_vars[$key]="$value"
  fi
done < "$env_name"

# 打印环境变量和传入值
print_vars() {
    echo "变量"
    echo "nnr_token: $nnr_token"
    echo "nnr_url: $nnr_url"
    echo "cf_key: $cf_key"
    echo "cf_email: $cf_email"
    echo "domain: $domain"
    echo "env_file: $env_file"
}

# 获取数据并写入文件
fetch_and_save_data() {
    FULL_URL="${nnr_url}/api/rules"
    RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -H "token: $nnr_token" "$FULL_URL")
    STATUS=$(echo $RESPONSE | jq .status)

    if [ "$STATUS" -eq 1 ]; then
        echo $RESPONSE | jq -r '.data[] | {name: (.name | split(" -> ")[0]), host: .host} | "{name=\"\(.name)\",host=\"\(.host)\"}"' | sort -u > /home/nnr.txt
        echo "数据已成功写入 /home/nnr.txt"
        cat /home/nnr.txt
    else
        echo "请求失败，错误信息: $(echo $RESPONSE | jq .data)"
    fi
}

# DDNS
ddns_update() {
    # 从 nnr.txt 读取数据
    declare -A ip_mapping
    while IFS= read -r line; do
        name_value=$(echo "$line" | grep -oP 'name="\K[^"]*')
        host_value=$(echo "$line" | grep -oP 'host="\K[^"]*')

        # 处理可能的多IP地址
        IFS=',' read -r -a ips <<< "$host_value"

        # 匹配 name* 和更新对应的 ip*
        for i in $(seq 1 100); do
            name_var="name$i"
            prefix_var="prefix$i"
            ip_var="ip$i"

            if [[ -n "${!name_var}" && "${!name_var}" == "$name_value" ]]; then
                for ((j = 0; j < ${#ips[@]}; j++)); do
                    if (( j == 0 )); then
                        suffix=""
                    else
                        suffix=$((j + 1))
                    fi
                    
                    # 更新变量名，以符合新的规则
                    new_name_var="name${i}${suffix}"
                    new_prefix_var="prefix${i}${suffix}"
                    new_ip_var="ip${i}${suffix}"

                    # 仅在未设置时更新或声明变量
                    [[ -z "${ip_mapping[$new_ip_var]}" ]] && {
                        eval "$new_name_var='${name_value}'"
                        eval "$new_prefix_var='${!prefix_var}${suffix}'"
                        eval "$new_ip_var='${ips[j]}'"
                        ip_mapping[$new_ip_var]=1  # 标记已设置
                    }
                done
                break # 防止重复处理相同的 name
            fi
        done
    done < /home/nnr.txt

    # 打印 name*, prefix*, ip* 的值，并询问是否继续
    echo "已解析的DDNS更新数据如下："
    for i in $(seq 1 100); do
        for suffix in "" {2..10}; do
            name_var="name${i}${suffix}"
            prefix_var="prefix${i}${suffix}"
            ip_var="ip${i}${suffix}"
            if [[ -n "${!name_var}" && -n "${!prefix_var}" && -n "${!ip_var}" ]]; then
                echo "${name_var}: ${!name_var}, ${prefix_var}: ${!prefix_var}, ${ip_var}: ${!ip_var}"
            fi
        done
    done

    read -p "是否继续执行DDNS更新？(y/n) " confirm
    if [[ $confirm == "y" ]]; then
        # 下载并执行 nnr-ddns.sh
        curl -L https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/nnr-ddns.sh -o nnr-ddns.sh && chmod +x nnr-ddns.sh
        # 对每个设置的IP进行DDNS更新
        for i in $(seq 1 100); do
            for suffix in "" {2..10}; do
                name_var="name${i}${suffix}"
                prefix_var="prefix${i}${suffix}"
                ip_var="ip${i}${suffix}"
                if [[ -n "${!name_var}" && -n "${!prefix_var}" && -n "${!ip_var}" ]]; then
                    ./nnr-ddns.sh -k "${cf_key}" -e "${cf_email}" -d "${domain}" -r "${!prefix_var}.${domain}" -t "A" -a "${!ip_var}"
                fi
            done
        done
    else
        echo "DDNS更新已取消。"
    fi
}

# 打印环境变量和传入值
print_vars

# 用户选择执行选项
if [ -z "$choice" ]; then
    echo "请选择执行选项：1. 全部执行 2. 执行获取规则ip 3. 执行 DDNS 更新" 0. 退出脚本
    read -r choice
fi

case $choice in
    1)
        echo "选择了全部执行"
        fetch_and_save_data
        ddns_update
        ;;
    2)
        echo "选择了执行获取规则ip"
        fetch_and_save_data
        ;;
    3)
        echo "选择了执行 DDNS 更新"
        ddns_update
        ;;
    0)
        exit 1
				;;
    *)
        echo " 无效的选择  "
        sleep 2s
    esac
esac
