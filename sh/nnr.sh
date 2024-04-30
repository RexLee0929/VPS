#!/bin/bash
env_help() {
	echo " Hello,初次使用请准备一个 $env_name 文件, 内容如下: "
	echo " cf_key=\"\" # Cloudflare API "
	echo " cf_email=\"\" # Cloudflare 邮箱 "
	echo " nnr_token=\"\" # nnr token "
	echo " nnr_url=\"https://nnr.moe\" # nnr 网址"
	echo " domain=\"\" # 用于 DNS 解析的域名 "
	echo " 具体 name prefix ip 后的数字根据你要ddns的规则数量来决定 "
	echo " name1=\"安徽CM-香港\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " name2=\"安徽CU-香港 x2\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " name3=\"广州CM-香港 x1.5\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " name4=\"广港IEPL1 x10\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " prefix1=\"nnr-ag-cm\" # 解析的域名前缀 "
	echo " prefix2=\"nnr-ag-cu\" # 解析的域名前缀 "
	echo " prefix3=\"nnr-gg\" # 解析的域名前缀 "
	echo " prefix4=\"nnr-gg-iepl\" # 解析的域名前缀 "
	echo " ip1=\"\" # 留空 "
	echo " ip2=\"\" # 留空 "
	echo " ip3=\"\" # 留空 "
	echo " ip4=\"\" # 留空 "
}
# 初始化变量
env_file="vps.env"
env_name="vps.env"
nnr_token=""
nnr_url=""
cf_key=""
cf_email=""
domain=""

# 解析命名参数
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

# 判断是否为URL
is_url() {
  if [[ $1 =~ ^https?:// ]]; then
    return 0
  else
    return 1
  fi
}

# 根据 env_file 值来决定操作
if is_url "$env_file"; then
  echo "从URL下载env文件：$env_file"
  curl -L "$env_file" -o "$env_name"
elif [ ! -f "$env_file" ]; then
  echo "未找到env文件"
  echo "env文件格式如下:"
  env_help
  echo "请输入文件地址以下载："
  read -r file_url
  if is_url "$file_url"; then
    curl -L "$file_url" -o "$env_name"
  else
    echo "提供的地址不是一个有效的URL。"
    exit 1
  fi
fi

# 读取环境变量文件
if [ -f "$env_name" ]; then
  source "$env_name"
else
  echo "未找到环境变量文件：$env_name"
  exit 1
fi

# 打印环境变量和传入值
print_vars() {
    echo "变量"
    echo "nnr_token: $nnr_token"
    echo "nnr_url: $nnr_url"
    echo "cf_key: $cf_key"
    echo "cf_email: $cf_email"
    echo "domain: $domain"
    echo "env_file: $env_file"
    echo "env_file: $env_name"
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


env_help() {
	echo " Hello,初次使用请准备一个 $env_name 文件, 内容如下: "
	echo " cf_key=\"\" # Cloudflare API "
	echo " cf_email=\"\" # Cloudflare 邮箱 "
	echo " nnr_token=\"\" # nnr token "
	echo " nnr_url=\"https://nnr.moe\" # nnr 网址"
	echo " domain=\"\" # 用于 DNS 解析的域名 "
	echo " 具体 name prefix ip 后的数字根据你要ddns的规则数量来决定 "
	echo " name1=\"安徽CM-香港\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " name2=\"安徽CU-香港 x2\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " name3=\"广州CM-香港 x1.5\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " name4=\"广港IEPL1 x10\" # 创建规则时自动创建的备注 \" ->\" 前的名称 不要留空格 "
	echo " prefix1=\"nnr-ag-cm\" # 解析的域名前缀 "
	echo " prefix2=\"nnr-ag-cu\" # 解析的域名前缀 "
	echo " prefix3=\"nnr-gg\" # 解析的域名前缀 "
	echo " prefix4=\"nnr-gg-iepl\" # 解析的域名前缀 "
	echo " ip1=\"\" # 留空 "
	echo " ip2=\"\" # 留空 "
	echo " ip3=\"\" # 留空 "
	echo " ip4=\"\" # 留空 "
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
