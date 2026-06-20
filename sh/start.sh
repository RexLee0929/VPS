#!/usr/bin/env bash
# start.sh
# 美化增强版：参考 ssh.sh 的颜色风格，为启动脚本增加清晰的彩色提示、步骤输出与错误提示
# 功能：
#  - 支持从 URL / 本地 env 文件加载
#  - 支持 DDNS / 代理安装 / 配置修改 / 哪吒探针安装
#  - 启动时检查 uzip，不存在则尝试使用 unzip 软链或自动安装

set -euo pipefail
IFS=$'\n\t'

# 颜色定义
c_yellow="\033[33m"
c_blue="\033[34m"
c_green="\033[32m"
c_red="\033[31m"
c_orange="\033[38;5;208m"
c_reset="\033[0m"

yellow() { printf "%b\n" "${c_yellow}$*${c_reset}"; }
blue()   { printf "%b\n" "${c_blue}$*${c_reset}"; }
green()  { printf "%b\n" "${c_green}$*${c_reset}"; }
red()    { printf "%b\n" "${c_red}$*${c_reset}"; }
orange() { printf "%b\n" "${c_orange}$*${c_reset}"; }

log()    { blue "[INFO] $*"; }
ok()     { green "[OK] $*"; }
warn()   { orange "[WARN] $*"; }
err()    { red "[ERROR] $*"; }
die()    { err "$*"; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [-f env_file_or_url] [-R record_prefix] [-S ss_node_id] [-V vmess_node_id] [-C choice] [-U nz_uuid]

选项:
  -f   指定 env 文件路径或 URL (默认: vps.env)
  -R   DNS 记录前缀 (record_prefix)
  -S   Shadowsocks 节点 ID (ss_node_id)
  -V   Vmess 节点 ID (vmess_node_id)
  -C   选择执行项 (0/1/2/3/4/5/6). 如果不提供将交互式提示
  -U   哪吒探针的 UUID (nz_uuid)
  -h   显示本帮助
EOF
}

# 包管理器检测
detect_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  else
    echo ""
  fi
}

install_package() {
  local pkg="$1"
  local mgr
  mgr="$(detect_pkg_mgr)"

  if [ -z "$mgr" ]; then
    die "无法检测到受支持的包管理器，请手动安装: $pkg"
  fi

  yellow "准备安装依赖包: $pkg"
  log "检测到包管理器: $mgr"

  case "$mgr" in
    apt) sudo apt-get update -y && sudo apt-get install -y "$pkg" ;;
    yum) sudo yum install -y "$pkg" ;;
    dnf) sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -Sy --noconfirm "$pkg" ;;
    apk) sudo apk add --no-cache "$pkg" ;;
    zypper) sudo zypper --non-interactive install -y "$pkg" ;;
    *) die "未实现的包管理器: $mgr" ;;
  esac

  ok "依赖安装完成: $pkg"
}

# 检查 uzip：没有则尝试安装 unzip
ensure_uzip() {
  yellow "检查 uzip/unzip 环境..."

  if command -v uzip >/dev/null 2>&1; then
    ok "检测到 uzip"
    return 0
  fi

  if command -v unzip >/dev/null 2>&1; then
    local unzip_path
    unzip_path="$(command -v unzip)"
    if [ -w /usr/local/bin ] || [ "$(id -u)" -eq 0 ]; then
      ln -sf "$unzip_path" /usr/local/bin/uzip
      chmod +x /usr/local/bin/uzip || true
      ok "已使用系统 unzip 创建 /usr/local/bin/uzip 软链 -> $unzip_path"
      return 0
    else
      warn "当前无权限直接写入 /usr/local/bin，尝试使用 sudo 创建 uzip 软链"
      sudo ln -sf "$unzip_path" /usr/local/bin/uzip
      sudo chmod +x /usr/local/bin/uzip || true
      ok "uzip 软链创建完成"
      return 0
    fi
  fi

  warn "未检测到 uzip 或 unzip，尝试自动安装 unzip"
  install_package "unzip"

  if command -v unzip >/dev/null 2>&1; then
    local unzip_path
    unzip_path="$(command -v unzip)"
    sudo ln -sf "$unzip_path" /usr/local/bin/uzip || true
    ok "已安装 unzip，并尝试创建 uzip 软链"
    return 0
  fi

  die "无法安装 unzip/uzip，请手动安装后重试"
}

# 下载工具
require_one_of() {
  for cmd in "$@"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

download() {
  # usage: download URL OUTPUT
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    log "使用 curl 下载: $url"
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    log "使用 wget 下载: $url"
    wget -qO "$out" "$url"
  else
    die "系统缺少 curl/wget，无法下载: $url"
  fi
}

# 参数解析
env_file="vps.env"
env_name="vps.env"
record_prefix=""
ss_node_id=""
vmess_node_id=""
choice=""
nz_uuid=""

while getopts ":f:R:S:V:C:U:h" opt; do
  case $opt in
    f) env_file="$OPTARG" ;;
    R) record_prefix="$OPTARG" ;;
    S) ss_node_id="$OPTARG" ;;
    V) vmess_node_id="$OPTARG" ;;
    C) choice="$OPTARG" ;;
    U) nz_uuid="$OPTARG" ;;
    h) usage; exit 0 ;;
    \?) err "无效选项: -$OPTARG"; usage; exit 2 ;;
    :)  err "选项 -$OPTARG 需要一个参数"; usage; exit 2 ;;
  esac
done

# 主流程开始
yellow "启动脚本开始执行..."
ensure_uzip

# 处理 env_file（支持 URL / 本地文件）
is_url() {
  [[ "$1" =~ ^https?:// ]]
}

yellow "处理环境变量文件..."

if is_url "$env_file"; then
  log "从 URL 下载 env 文件: $env_file -> $env_name"
  download "$env_file" "$env_name"
  ok "env 文件下载完成"
elif [ ! -f "$env_file" ]; then
  warn "未找到 env 文件: $env_file"
  printf "请输入要下载的 env 文件 URL: "
  read -r file_url
  if is_url "$file_url"; then
    download "$file_url" "$env_name"
    ok "env 文件下载完成"
  else
    die "提供的地址不是有效的 URL"
  fi
else
  if [ "$env_file" != "$env_name" ]; then
    cp -f "$env_file" "$env_name"
    ok "已复制 env 文件到: $env_name"
  else
    ok "使用本地 env 文件: $env_name"
  fi
fi

if [ ! -f "$env_name" ]; then
  die "env 文件不存在: $env_name"
fi

# 读取 env 文件
yellow "读取环境变量文件: $env_name"

declare -A env_vars
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
  if [[ $line =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
    key="${line%%=*}"
    value="${line#*=}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    env_vars[$key]="$value"
  fi
done < "$env_name"

cf_key="${env_vars[cf_key]:-}"
cf_email="${env_vars[cf_email]:-}"
domain1="${env_vars[domain1]:-}"
domain2="${env_vars[domain2]:-}"
v2board_webapi_url="${env_vars[v2board_webapi_url]:-}"
v2board_webapi_key="${env_vars[v2board_webapi_key]:-}"
nezha_panel_ip="${env_vars[nezha_panel_ip]:-}"
nezha_panel_port="${env_vars[nezha_panel_port]:-}"
nezha_panel_tls="${env_vars[nezha_panel_tls]:-}"
nezha_agent_key="${env_vars[nezha_agent_key]:-}"

yellow "已加载环境变量（部分）:"
echo "cf_key: ${cf_key:-<未设置>}"
echo "cf_email: ${cf_email:-<未设置>}"
echo "domain1: ${domain1:-<未设置>}"
echo "domain2: ${domain2:-<未设置>}"
echo "v2board_webapi_url: ${v2board_webapi_url:-<未设置>}"
echo "v2board_webapi_key: ${v2board_webapi_key:-<未设置>}"
echo "nezha_panel_ip: ${nezha_panel_ip:-<未设置>}"
echo "nezha_panel_port: ${nezha_panel_port:-<未设置>}"
echo "nezha_panel_tls: ${nezha_panel_tls:-<未设置>}"
echo "nezha_agent_key: ${nezha_agent_key:-<未设置>}"
echo

yellow "传入参数（部分）:"
echo "env_file: $env_file"
echo "record_prefix: ${record_prefix:-<未设置>}"
echo "ss_node_id: ${ss_node_id:-<未设置>}"
echo "vmess_node_id: ${vmess_node_id:-<未设置>}"
echo "nz_uuid: ${nz_uuid:-<未设置>}"
echo

# 交互选择
if [ -z "${choice:-}" ]; then
  yellow "请选择执行选项："
  echo "1. 全部执行"
  echo "2. 执行 DDNS"
  echo "3. 安装代理"
  echo "4. 修改配置文件"
  echo "5. 安装哪吒探针"
  echo "6. 安装代理并修改配置文件"
  echo "0. 退出"
  read -rp "请输入数字 [0/1/2/3/4/5/6]: " choice
fi

# 功能函数
execute_ddns() {
  yellow "开始执行 DDNS..."
  if [ -z "$cf_key" ] || [ -z "$cf_email" ] || [ -z "$domain1" ]; then
    err "执行 DDNS 需要 cf_key / cf_email / domain1，当前缺失，跳过 DDNS"
    return 1
  fi

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN

  download "https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/ddns.sh" "$tmp"
  chmod +x "$tmp"

  "$tmp" -k "${cf_key}" -e "${cf_email}" -d "${domain1}" -r "${record_prefix}.${domain1}" -t "A" -p "false"
  "$tmp" -k "${cf_key}" -e "${cf_email}" -d "${domain1}" -r "${record_prefix}-v6.${domain1}" -t "AAAA" -p "false"

  if [ -n "${domain2:-}" ]; then
    "$tmp" -k "${cf_key}" -e "${cf_email}" -d "${domain2}" -r "${record_prefix}.${domain2}" -t "A" -p "true"
  fi

  ok "DDNS 执行完成"
}

install_proxy() {
  yellow "开始安装代理（soga）..."
  local arch sudo_cmd

  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l|armv7) arch="arm" ;;
    *) arch="amd64" ;;
  esac

  if [ -w /usr/bin ] || [ "$(id -u)" -eq 0 ]; then
    sudo_cmd=""
  else
    sudo_cmd="sudo"
  fi

  log "检测到架构: $arch"
  log "下载 soga 管理脚本到 /usr/bin/soga"
  $sudo_cmd bash -c "curl -fsSL -o /usr/bin/soga https://github.com/vaxilu/soga-cmd/releases/latest/download/soga-cmd-linux-${arch} || wget -qO /usr/bin/soga https://github.com/vaxilu/soga-cmd/releases/latest/download/soga-cmd-linux-${arch}"
  $sudo_cmd chmod +x /usr/bin/soga

  log "更新 soga 版本为 2.13.4"
  $sudo_cmd soga update 2.13.4 || warn "soga update 返回非零状态（可忽略）"

  log "创建 soga 实例: ss / vmess"
  $sudo_cmd soga new ss || warn "ss 实例可能已存在"
  $sudo_cmd soga new vmess || warn "vmess 实例可能已存在"

  ok "代理安装与实例创建完成"
}

modify_config_files() {
  yellow "开始修改配置文件..."
  if [ -z "$v2board_webapi_url" ] || [ -z "$v2board_webapi_key" ]; then
    err "修改配置需要 v2board_webapi_url 与 v2board_webapi_key，当前缺失，跳过配置修改"
    return 1
  fi

  local tmp_ss tmp_vmess
  tmp_ss="$(mktemp)"
  tmp_vmess="$(mktemp)"
  trap 'rm -f "$tmp_ss" "$tmp_vmess"' RETURN

  download "https://raw.githubusercontent.com/RexLee0929/VPS/main/config/soga-ss.conf" "$tmp_ss"
  download "https://raw.githubusercontent.com/RexLee0929/VPS/main/config/soga-vmess.conf" "$tmp_vmess"

  sudo mv "$tmp_ss" /etc/soga/ss/soga.conf
  sudo mv "$tmp_vmess" /etc/soga/vmess/soga.conf

  sudo sed -i "s/node_id=.*/node_id=${ss_node_id}/g" /etc/soga/ss/soga.conf || true
  sudo sed -i "s|webapi_url=.*|webapi_url=${v2board_webapi_url}|g" /etc/soga/ss/soga.conf || true
  sudo sed -i "s/webapi_key=.*/webapi_key=${v2board_webapi_key}/g" /etc/soga/ss/soga.conf || true

  sudo sed -i "s/node_id=.*/node_id=${vmess_node_id}/g" /etc/soga/vmess/soga.conf || true
  sudo sed -i "s|webapi_url=.*|webapi_url=${v2board_webapi_url}|g" /etc/soga/vmess/soga.conf || true
  sudo sed -i "s/webapi_key=.*/webapi_key=${v2board_webapi_key}/g" /etc/soga/vmess/soga.conf || true

  log "尝试启动并启用 ss/vmess"
  sudo soga start ss || warn "soga start ss 返回非零（可忽略）"
  sudo soga start vmess || warn "soga start vmess 返回非零（可忽略）"
  sudo soga enable ss || true
  sudo soga enable vmess || true

  ok "配置文件修改完成，实例已尝试启动并启用开机启动"
}

install_nezha_agent() {
  yellow "开始安装哪吒探针..."
  local tmp_nezha env_vars_cmd
  tmp_nezha="$(mktemp)"
  trap 'rm -f "$tmp_nezha"' RETURN

  download "https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh" "$tmp_nezha"
  chmod +x "$tmp_nezha"

  if [ -z "$nezha_panel_ip" ] || [ -z "$nezha_panel_port" ] || [ -z "$nezha_agent_key" ]; then
    err "安装哪吒探针需要 nezha_panel_ip / nezha_panel_port / nezha_agent_key，当前缺失，跳过"
    return 1
  fi

  env_vars_cmd="NZ_SERVER=\"${nezha_panel_ip}:${nezha_panel_port}\" NZ_TLS=\"${nezha_panel_tls:-false}\" NZ_CLIENT_SECRET=\"${nezha_agent_key}\""
  if [ -n "${nz_uuid:-}" ]; then
    env_vars_cmd="${env_vars_cmd} NZ_UUID=\"${nz_uuid}\""
  fi

  log "运行哪吒安装脚本..."
  eval sudo $env_vars_cmd "$tmp_nezha"

  ok "哪吒探针安装完成（若安装脚本执行成功）"
}

# 根据选择执行
yellow "开始执行所选操作: $choice"

case "$choice" in
  1)
    execute_ddns || true
    install_proxy || true
    modify_config_files || true
    install_nezha_agent || true
    ;;
  2)
    execute_ddns
    ;;
  3)
    install_proxy
    ;;
  4)
    modify_config_files
    ;;
  5)
    install_nezha_agent
    ;;
  6)
    install_proxy
    modify_config_files
    ;;
  0)
    warn "用户选择退出"
    exit 0
    ;;
  *)
    err "无效的选择: $choice"
    usage
    exit 2
    ;;
esac

green "脚本执行完毕"
