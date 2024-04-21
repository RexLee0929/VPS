#!/bin/bash

# 定义变量
env_file="env_vps.txt"
record_prefix=""
ss_node_id=""
vmess_node_id=""
nezha_key=""

choice=""

# 使用getopts解析命名参数
while getopts "f:R:S:V:C:K:" opt; do
  case $opt in
    f) env_file="$OPTARG";;
    R) record_prefix="$OPTARG";;
    S) ss_node_id="$OPTARG";;
    V) vmess_node_id="$OPTARG";;
    c) choice="$OPTARG";;
    K) nezha_key="$OPTARG";; # 新增处理哪吒探针密钥的选项
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
  echo "从URL下载env文件：$env_file"
  curl -L "$env_file" -o "env_vps.txt"
  env_file="env_vps.txt"
elif [ ! -f "$env_file" ]; then
  echo "未找到env文件。请输入文件地址以下载："
  read -r file_url
  curl -L "$file_url" -o "env_vps.txt"
  env_file="env_vps.txt"
fi

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
done < "env_vps.txt"

# 从文件中读取值
cf_key="${env_vars[cf_key]}"
cf_email="${env_vars[cf_email]}"
domain1="${env_vars[domain1]}"
domain2="${env_vars[domain2]}"
v2board_webapi_url="${env_vars[v2board_webapi_url]}"
v2board_webapi_key="${env_vars[v2board_webapi_key]}"
nezha_panel_ip="${env_vars[nezha_panel_ip]}" # 新增读取哪吒面板IP的变量
nezha_panel_port="${env_vars[nezha_panel_port]}" # 新增读取哪吒面板端口的变量


# 打印环境变量
echo "环境变量"
echo "nezha_panel_port: ${env_vars[nezha_panel_port]}"
echo "cf_key: ${env_vars[cf_key]}"
echo "cf_email: ${env_vars[cf_email]}"
echo "domain1: ${env_vars[domain1]}"
echo "domain2: ${env_vars[domain2]}"
echo "v2board_webapi_url: ${env_vars[v2board_webapi_url]}"
echo "v2board_webapi_key: ${env_vars[v2board_webapi_key]}"
echo "nezha_panel_ip: ${env_vars[nezha_panel_ip]}"
echo "nezha_panel_port: ${env_vars[nezha_panel_port]}"

# 打印传入值
echo "传入值"
echo "env_file: ${env_file}"
echo "record_prefix: ${record_prefix}"
echo "ss_node_id: ${ss_node_id}"
echo "vmess_node_id: ${vmess_node_id}"
echo "nezha_key: ${nezha_key}"

# 用户选择执行选项
if [ -z "$choice" ]; then
  echo "请选择执行选项：1. 全部执行 2. 执行DDNS 3. 安装代理 4. 修改配置文件 5. 安装哪吒探针 0.退出脚本"
  read -r choice
fi

execute_ddns() {
  # DDNS更新部分
  echo "执行DDNS脚本..."
  curl -L https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/ddns.sh -o ddns.sh && chmod +x ddns.sh
  ./ddns.sh -k "${cf_key}" -e "${cf_email}" -d "${domain1}" -r "${record_prefix}.${domain1}" -t "A" -p "false"
  ./ddns.sh -k "${cf_key}" -e "${cf_email}" -d "${domain1}" -r "${record_prefix}-v6.${domain1}" -t "AAAA" -p "false"
  ./ddns.sh -k "${cf_key}" -e "${cf_email}" -d "${domain2}" -r "${record_prefix}.${domain2}" -t "A" -p "true"
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

  sed -i "s/node_id=.*/node_id=${ss_node_id}/g" /etc/soga/soga.conf
  sed -i "s|webapi_url=.*|webapi_url=${v2board_webapi_url}|g" /etc/soga/soga.conf
  sed -i "s/webapi_key=.*/webapi_key=${v2board_webapi_key}/g" /etc/soga/soga.conf

  sed -i "s/NodeID: .*/NodeID: ${vmess_node_id}/g" /etc/XrayR/config.yml
  sed -i "s|ApiHost: \".*\"|ApiHost: \"${v2board_webapi_url}\"|g" /etc/XrayR/config.yml
  sed -i "s/ApiKey: \".*\"/ApiKey: \"${v2board_webapi_key}\"/g" /etc/XrayR/config.yml

  echo "配置文件修改完成"

  soga start

  xrayr start
}


# 定义安装哪吒探针的函数
install_nezha_agent() {
  echo "安装哪吒探针..."
  if [ -z "$nezha_key" ]; then
    echo "请输入哪吒探针密钥："
    read -r nezha_key
  fi
  curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh install_agent "${nezha_panel_ip}" "${nezha_panel_port}" "${nezha_key}"
}

case $choice in
  1)
    execute_ddns
    install_proxy
    modify_config_files
    install_nezha_agent
    ;; # 全部执行
  2) execute_ddns ;; # 只执行DDNS更新
  3) install_proxy ;; # 只安装代理服务
  4) modify_config_files ;; # 只修改配置文件
  5) install_nezha_agent ;; # 新增的哪吒探针安装选项
  0) exit 1 ;;
  *) echo "无效的选择：$choice" ;;
esac
