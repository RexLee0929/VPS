#!/bin/bash

# 定义变量
env_file="env_vps.txt"
prefix=""
node_id1=""
node_id2=""
choice=""

# 使用getopts解析命名参数
while getopts "f:p:i:I:c:" opt; do
  case $opt in
    f) env_file="$OPTARG";;
    p) prefix="$OPTARG";;
    i) node_id1="$OPTARG";;
    I) node_id2="$OPTARG";;
    c) choice="$OPTARG";;
    \?) echo "无效选项: -$OPTARG" >&2;;
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
  # 是URL，直接下载
  echo "从URL下载env文件：$env_file"
  curl -L "$env_file" -o "env_vps.txt"
  env_file="env_vps.txt"  # 更新env_file变量为下载的文件名
elif [ ! -f "$env_file" ]; then
  # 文件不存在，提示用户输入
  echo "未找到env文件。请输入文件地址以下载："
  read -r file_url
  curl -L "$file_url" -o "env_vps.txt"
  env_file="env_vps.txt"  # 更新env_file变量为下载的文件名
fi

# 读取环境变量文件
declare -A env_vars
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ $line =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*= ]]; then
    key="${line%%=*}"
    value="${line#*=}"
    env_vars[$key]="$value"
  fi
done < "$env_file"

# 从文件中读取值
key="${env_vars[key]}"
email="${env_vars[email]}"
domain1="${env_vars[domain1]}"
domain2="${env_vars[domain2]}"
webapi_url="${env_vars[webapi_url]}"
webapi_key="${env_vars[webapi_key]}"

# 用户选择执行选项
if [ -z "$choice" ]; then
  echo "请选择执行选项：1. 全部执行 2. 执行DDNS 3. 安装代理 4. 修改配置文件 0.退出脚本"
  read -r choice
fi

execute_ddns() {
  # DDNS更新部分
  echo "执行DDNS脚本..."
  curl -L https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/ddns.sh -o ddns.sh && chmod +x ddns.sh
  ./ddns.sh -k "${key}" -u "${email}" -z "${domain1}" -h "${prefix}.${domain1}" -t "A" -p "false"
  ./ddns.sh -k "${key}" -u "${email}" -z "${domain1}" -h "${prefix}-v6.${domain1}" -t "AAAA" -p "false"
  ./ddns.sh -k "${key}" -u "${email}" -z "${domain2}" -h "${prefix}.${domain2}" -t "A" -p "true"
}

install_proxy() {
  # 代理安装部分
  echo "安装代理服务..."
  curl -Ls https://github.com/sprov065/soga/raw/master/soga.sh | bash -s -- install
  curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh | bash
}

modify_config_files() {
  # 修改配置文件部分
  echo "修改配置文件..."
  curl -L https://raw.githubusercontent.com/RexLee0929/VPS/main/config/xrayr.yml -o /etc/XrayR/config.yml
  curl -L https://raw.githubusercontent.com/RexLee0929/VPS/main/config/soga.conf -o /etc/soga/soga.conf

  sed -i "s/node_id=.*/node_id=${node_id1}/g" /etc/soga/soga.conf
  sed -i "s|webapi_url=.*|webapi_url=${webapi_url}|g" /etc/soga/soga.conf
  sed -i "s/webapi_key=.*/webapi_key=${webapi_key}/g" /etc/soga/soga.conf

  sed -i "s/NodeID: .*/NodeID: ${node_id2}/g" /etc/XrayR/config.yml
  sed -i "s|ApiHost: \".*\"|ApiHost: \"${webapi_url}\"|g" /etc/XrayR/config.yml
  sed -i "s/ApiKey: \".*\"/ApiKey: \"${webapi_key}\"/g" /etc/XrayR/config.yml

  echo "配置文件修改完成"

  soga start

  xrayr start
}

case $choice in
  1)
    # 全部执行
    execute_ddns
    install_proxy
    modify_config_files
    ;;
  2)
    # 只执行DDNS更新
    execute_ddns
    ;;
  3)
    # 只安装代理服务
    install_proxy
    ;;
  4)
    # 只修改配置文件
    modify_config_files
    ;;
  0 )
    exit 1
    ;;
  *)
    echo "无效的选择：$choice"
    ;;
esac
