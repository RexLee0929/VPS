#!/usr/bin/env bash
# start.sh
# 优化与增强版脚本：支持从 URL / 本地 env 文件加载、参数解析、DDNS / 代理 / 哪吒 探针 操作
# 开始时会检查 uzip（如果不存在且系统有 unzip 则建立软链；都不存在则尝试安装 unzip），并尽量自动处理包管理器安装
set -euo pipefail
IFS=$'\n\t'

# 通用日志与帮助函数
log()   { printf '%s\n' "$*"; }
err()   { printf 'ERROR: %s\n' "$*" >&2; }
die()   { err "$*"; exit 1; }

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

  log "使用包管理器 ($mgr) 安装: $pkg"
  case "$mgr" in
    apt) sudo apt-get update -y && sudo apt-get install -y "$pkg" ;;
    yum) sudo yum install -y "$pkg" ;;
    dnf) sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -Sy --noconfirm "$pkg" ;;
    apk) sudo apk add --no-cache "$pkg" ;;
    zypper) sudo zypper --non-interactive install -y "$pkg" ;;
    *) die "未实现的包管理器: $mgr" ;;
  esac
}

# 检查 uzip：若无，尝试安装 unzip
ensure_uzip() {
  if command -v uzip >/dev/null 2>&1; then
    log "检测到 uzip"
    return 0
  fi

  if command -v unzip >/dev/null 2>&1; then
    local unzip_path
    unzip_path="$(command -v unzip)"
    if [ -w /usr/local/bin ] || [ "$(id -u)" -eq 0 ]; then
      ln -sf "$unzip_path" /usr/local/bin/uzip
      chmod +x /usr/local/bin/uzip || true
      log "使用系统的 unzip 并创建 /usr/local/bin/uzip 软链 -> $unzip_path"
      return 0
    else
      log "需要 root 权限以创建 /usr/local/bin/uzip 软链，尝试使用 sudo"
      sudo ln -sf "$unzip_path" /usr/local/bin/uzip
      sudo chmod +x /usr/local/bin/uzip || true
      log "软链创建完成"
      return 0
    fi
  fi

  log "未检测到 uzip 或 unzip，尝试安装 unzip 包"
  install_package "unzip"
  if command -v unzip >/dev/null 2>&1; then
    local unzip_path
    unzip_path="$(command -v unzip)"
    sudo ln -sf "$unzip_path" /usr/local/bin/uzip || true
    log "安装 unzip 完成并尝试创建 uzip 软链"
    return 0
  fi

  die "无法安装 unzip/uzip，请手动安装后重试"
}

# 基本命令可用性 / 下载工具 选择
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
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    die "系统缺少 curl/wget，无法下载 $url"
  fi
}

# 脚本正文
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
    f) env_file="$OPTARG";;
    R) record_prefix="$OPTARG";;
    S) ss_node_id="$OPTARG";;
    V) vmess_node_id="$OPTARG";;
    C) choice="$OPTARG";;
    U) nz_uuid="$OPTARG";;
    h) usage; exit 0;;
    \?) err "无效选项: -$OPTARG"; usage; exit 2;;
    :)  err "选项 -$OPTARG 需要一个参数"; usage; exit 2;;
  esac
done


# 主流程开始：确保 uzip存在
ensure_uzip

# 处理 env_file（支持 URL 或 本地文件）
# 如果 -f 给的是 URL，则下载到 env_name（默认 vps.env）
is_url() {
  [[ "$1" =~ ^https?:// ]]
}

if is_url "$env_file"; then
  log "从 URL 下载 env 文件: $env_file -> $env_name"
  download "$env_file" "$env_name"
elif [ ! -f "$env_file" ]; then
  log "未找到 env 文件: $env_file"
  printf "请输入要下载的 env 文件 URL: "
  read -r file_url
  if is_url "$file_url"; then
    download "$file_url" "$env_name"
  else
    die "提供的地址不是有效的 URL"
  fi
else
  # 本地文件存在，复制/使用它作为 env_name（避免覆盖默认文件名）
  if [ "$env_file" != "$env_name" ]; then
    cp -f "$env_file" "$env_name"
  fi
fi

# 确认 env 文件存在且可读
if [ ! -f "$env_name" ]; then
  die "env 文件不存在: $env_name"
fi

# 读取 env 文件为关联数组
declare -A env_vars
while IFS= read -r line || [[ -n "$line" ]]; do
  # 忽略注释与空行
  [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
  if [[ $line =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
    key="${line%%=*}"
    value="${line#*=}"
    # 去除两端引号
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    env_vars[$key]="$value"
  fi
done < "$env_name"

# 从 env_vars 中提取可能需要的变量（如果存在）
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

# 打印关键信息（可选）
log "已加载环境变量 (部分):"
log "  cf_key: ${cf_key:-<未设置>}"
log "  cf_email: ${cf_email:-<未设置>}"
log "  domain1: ${domain1:-<未设置>}"
log "  domain2: ${domain2:-<未设置>}"
log "  v2board_webapi_url: ${v2board_webapi_url:-<未设置>}"
log "  v2board_webapi_key: ${v2board_webapi_key:-<未设置>}"
log "  nezha_panel_ip: ${nezha_panel_ip:-<未设置>}"
log "  nezha_panel_port: ${nezha_panel_port:-<未设置>}"
log "  nezha_panel_tls: ${nezha_panel_tls:-<未设置>}"
log "  nezha_agent_key: ${nezha_agent_key:-<未设置>}"

log "传入参数 (部分):"
log "  env_file: $env_file"
log "  record_prefix: ${record_prefix:-<未设置>}"
log "  ss_node_id: ${ss_node_id:-<未设置>}"
log "  vmess_node_id: ${vmess_node_id:-<未设置>}"
log "  nz_uuid: ${nz_uuid:-<未设置>}"

# 交互选择
if [ -z "${choice:-}" ]; then
  cat <<EOF
请选择执行选项：
 1. 全部执行
 2. 执行 DDNS
 3. 安装代理
 4. 修改配置文件
 5. 安装哪吒探针
 6. 安装代理并修改配置文件
 0. 退出
EOF
  printf "请输入数字: "
  read -r choice
fi

# 各功能函数
execute_ddns() {
  if [ -z "$cf_key" ] || [ -z "$cf_email" ] || [ -z "$domain1" ]; then
    err "执行 DDNS 需要 cf_key / cf_email / domain1，当前缺失，跳过 DDNS"
    return 1
  fi
  log "执行 DDNS 脚本..."
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' RETURN
  download "https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/ddns.sh" "$tmp"
  chmod +x "$tmp"
  "$tmp" -k "${cf_key}" -e "${cf_email}" -d "${domain1}" -r "${record_prefix}.${domain1}" -t "A" -p "false"
  "$tmp" -k "${cf_key}" -e "${cf_email}" -d "${domain1}" -r "${record_prefix}-v6.${domain1}" -t "AAAA" -p "false"
  if [ -n "${domain2:-}" ]; then
    "$tmp" -k "${cf_key}" -e "${cf_email}" -d "${domain2}" -r "${record_prefix}.${domain2}" -t "A" -p "true"
  fi
  log "DDNS 完成"
}

install_proxy() {
  log "开始安装 soga 管理脚本与 soga 实例"
  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l|armv7) arch="arm" ;;
    *) arch="amd64" ;;
  esac

  # 下载 soga 管理脚本二进制到 /usr/bin/soga
  if [ -w /usr/bin ] || [ "$(id -u)" -eq 0 ]; then
    sudo_cmd=""
  else
    sudo_cmd="sudo"
  fi

  log "下载 soga 管理脚本 (arch=${arch}) 到 /usr/bin/soga"
  $sudo_cmd bash -c "curl -fsSL -o /usr/bin/soga https://github.com/vaxilu/soga-cmd/releases/latest/download/soga-cmd-linux-${arch} || wget -qO /usr/bin/soga https://github.com/vaxilu/soga-cmd/releases/latest/download/soga-cmd-linux-${arch}"
  $sudo_cmd chmod +x /usr/bin/soga

  log "更新 soga 版本为 2.13.4 并创建实例"
  $sudo_cmd soga update 2.13.4 || log "soga update 命令返回非零状态（可忽略）"
  $sudo_cmd soga new ss || log "创建 ss 实例（可能已存在）"
  $sudo_cmd soga new vmess || log "创建 vmess 实例（可能已存在）"

  log "soga 安装与实例创建完成"
}

modify_config_files() {
  log "开始修改配置文件..."
  # 确保 webapi 与 node id 提供
  if [ -z "$v2board_webapi_url" ] || [ -z "$v2board_webapi_key" ]; then
    err "修改配置需要 v2board_webapi_url 与 v2board_webapi_key，当前缺失，跳过配置修改"
    return 1
  fi

  # 下载配置模版到临时文件后再替换到目标位置
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

  log "配置文件修改完成，尝试启动并启用开机启动"
  sudo soga start ss || log "soga start ss 返回非零（可忽略）"
  sudo soga start vmess || log "soga start vmess 返回非零（可忽略）"
  sudo soga enable ss || true
  sudo soga enable vmess || true
  log "实例已启动并设置为开机启动 (如支持)"
}

install_nezha_agent() {
  log "安装哪吒探针..."
  tmp_nezha="$(mktemp)"
  trap 'rm -f "$tmp_nezha"' RETURN
  download "https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh" "$tmp_nezha"
  chmod +x "$tmp_nezha"

  # 组装环境变量
  if [ -z "$nezha_panel_ip" ] || [ -z "$nezha_panel_port" ] || [ -z "$nezha_agent_key" ]; then
    err "安装哪吒探针需要 nezha_panel_ip/nezhapanel_port/nezha_agent_key，当前缺失，跳过"
    return 1
  fi

  env_vars_cmd="NZ_SERVER=\"${nezha_panel_ip}:${nezha_panel_port}\" NZ_TLS=\"${nezha_panel_tls:-false}\" NZ_CLIENT_SECRET=\"${nezha_agent_key}\""
  if [ -n "${nz_uuid:-}" ]; then
    env_vars_cmd="${env_vars_cmd} NZ_UUID=\"${nz_uuid}\""
  fi

  log "运行哪吒安装脚本..."
  eval sudo $env_vars_cmd "$tmp_nezha"
  log "哪吒探针安装完成（如果脚本成功）"
}

# 根据选择执行
case "$choice" in
  1)
    execute_ddns || true
    install_proxy || true
    modify_config_files || true
    install_nezha_agent || true
    ;;
  2) execute_ddns ;;
  3) install_proxy ;;
  4) modify_config_files ;;
  5) install_nezha_agent ;;
  6)
    install_proxy
    modify_config_files
    ;;
  0) log "退出"; exit 0 ;;
  *)
    err "无效的选择：$choice"
    usage
    exit 2
    ;;
esac

log "脚本执行完毕"
