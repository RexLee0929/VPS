#!/usr/bin/env bash
# ==============================================================================
#  ssh.sh — SSH 配置与公钥管理脚本
#  版本 : v2.0
#  规范 : sh/UNIFIED v2（与 ddns.sh / env.sh / start.sh 共用同一套写法）
#
#  这次重构要解决的事：
#    · 短选项与 start.sh 撞车（-R 在 ssh 是 root 登录、在 start 是记录前缀；
#      -U 在 ssh 是公钥认证、在 start 是哪吒 UUID）→ 长选项成为唯一权威接口
#    · 参数漏传 → 缺失项一次性列全
#    · 取值来源统一为：命令行 > VPS_* 环境变量 > env 文件 > 内置默认
#
#  示例:
#    ./ssh.sh --port=2222 --root-login=no --password-auth=no --pubkey="$(cat ~/.ssh/id_ed25519.pub)"
#    ./ssh.sh --env=ssh.env --choice=1 --dry-run
# ==============================================================================

# ------------------------------------------------------------------------------
#  公共区段 v2.0 —— ddns.sh / ssh.sh / env.sh / start.sh / proxy.sh / nezha.sh 完全一致
#  ---------------------------------------------------------------------------
#  传参约定（全部脚本统一）：
#    1. 长选项是唯一权威接口：--key value 或 --key=value
#       短选项仅为兼容保留，跨脚本含义可能不同 → 串联执行一律用长选项
#    2. 取值优先级：命令行 > VPS_* 环境变量 > env 文件 > 内置默认
#    3. 缺失参数一次性列全，并给出可复制的补全方式
#    4. 通用开关：--dry-run --yes --no-color --verbose --help --version
#    5. 敏感值打印一律脱敏（显示前 4 后 4 与长度）
#  修改本区段时请同步其余各脚本。
# ------------------------------------------------------------------------------
set -uo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0" .sh)"
SCRIPT_VERSION="2.0.0"

# ---------- 颜色 ----------
USE_COLOR=1
[ -t 1 ] || USE_COLOR=0
[ -n "${NO_COLOR:-}" ] && USE_COLOR=0
case " $* " in *" --no-color "*) USE_COLOR=0 ;; esac
case " $* " in *" --color "*)    USE_COLOR=1 ;; esac

init_colors() {
  if [ "$USE_COLOR" -eq 1 ]; then
    c_reset=$'\033[0m';   c_bold=$'\033[1m'
    c_red=$'\033[31m';    c_green=$'\033[32m'
    c_yellow=$'\033[33m'; c_blue=$'\033[34m'
    c_orange=$'\033[38;5;208m'; c_cyan=$'\033[36m'; c_gray=$'\033[90m'
  else
    c_reset=""; c_bold=""; c_red=""; c_green=""
    c_yellow=""; c_blue=""; c_orange=""; c_cyan=""; c_gray=""
  fi
}
init_colors

# ---------- 日志 ----------
log()  { printf '%s%-7s%s %s\n' "$c_blue"   "[INFO]"  "$c_reset" "$*"; }
ok()   { printf '%s%-7s%s %s\n' "$c_green"  "[OK]"    "$c_reset" "$*"; }
warn() { printf '%s%-7s%s %s\n' "$c_orange" "[WARN]"  "$c_reset" "$*"; }
err()  { printf '%s%-7s%s %s\n' "$c_red"    "[ERROR]" "$c_reset" "$*" >&2; }
step() { printf '%s%-7s%s %s\n' "$c_cyan"   "[STEP]"  "$c_reset" "$*"; }
die()  { err "$*"; exit 1; }

RULE="────────────────────────────────────────────────────────────"
line()    { printf '%s%s%s\n' "$c_gray" "$RULE" "$c_reset"; }
section() { printf '\n%s%s%s\n' "$c_bold" "$1" "$c_reset"; line; }

mask() {
  local s="$1"
  case "${#s}" in
    0)                    printf '%s' "" ;;
    1|2|3|4|5|6|7|8)      printf '%s' "********" ;;
    *)                    printf '%s…%s(%s字符)' "${s:0:4}" "${s: -4}" "${#s}" ;;
  esac
}

kv() {
  local k="$1" v="$2" sec="${3:-no}"
  [ "$sec" = "yes" ] && [ -n "$v" ] && v="$(mask "$v")"
  printf '  %s%-18s%s : %s%s%s\n' "$c_cyan" "$k" "$c_reset" "$c_orange" "${v:-<未设置>}" "$c_reset"
}

kv3() {
  local k="$1" v="$2" s="$3" sec="${4:-no}"
  [ "$sec" = "yes" ] && [ -n "$v" ] && v="$(mask "$v")"
  printf '  %s%-18s%s : %s%-26s%s %s(%s)%s\n' \
    "$c_cyan" "$k" "$c_reset" "$c_orange" "${v:-<未设置>}" "$c_reset" "$c_gray" "$s" "$c_reset"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }
is_url()   { [[ "$1" =~ ^https?:// ]]; }

download() {
  local url="$1" out="$2"
  if have_cmd curl; then curl -fsSL "$url" -o "$out"
  elif have_cmd wget; then wget -qO "$out" "$url"
  else die "系统缺少 curl/wget，无法下载: $url"; fi
}

# ---------- 依赖：包管理器 / 解压工具（各脚本的自身部分可直接调用） ----------
sudo_cmd=""
if [ ! -w /usr/bin ] && [ "$(id -u)" -ne 0 ]; then sudo_cmd="sudo"; fi

detect_pkg_mgr() {
  local m
  for m in apt-get yum dnf pacman apk zypper; do
    have_cmd "$m" && { printf '%s' "${m%-get}"; return 0; }
  done
  printf ''
}

install_package() {
  local pkg="$1" mgr
  mgr="$(detect_pkg_mgr)"
  [ -n "$mgr" ] || die "无法识别包管理器，请手动安装: $pkg"
  step "安装依赖 ${pkg}（${mgr}）..."
  case "$mgr" in
    apt)    $sudo_cmd apt-get update -y && $sudo_cmd apt-get install -y "$pkg" ;;
    yum)    $sudo_cmd yum install -y "$pkg" ;;
    dnf)    $sudo_cmd dnf install -y "$pkg" ;;
    pacman) $sudo_cmd pacman -Sy --noconfirm "$pkg" ;;
    apk)    $sudo_cmd apk add --no-cache "$pkg" ;;
    zypper) $sudo_cmd zypper --non-interactive install -y "$pkg" ;;
  esac
}

ensure_unzip() {
  if have_cmd unzip; then
    ok "检测到 unzip: $(command -v unzip)"
    return 0
  fi
  warn "未检测到 unzip，尝试安装（解压 .zip 需要）"
  install_package "unzip"
  have_cmd unzip || die "unzip 安装失败，请手动安装后重试"
  ok "unzip 安装完成: $(command -v unzip)"
}

# ---------- 选项表 ----------
declare -A OPT_LONG OPT_SHORT OPT_RSHORT OPT_TAKE OPT_VAR OPT_DESC OPT_SET
OPT_ORDER=()
DRY_RUN=0; ASSUME_YES=0; VERBOSE=0
POSITIONAL=(); NORM_ARGS=(); MISSING=()

def_opt() {
  local lo="$1" sh="$2" take="$3" var="$4" desc="$5"
  OPT_ORDER+=("$lo")
  OPT_LONG["--$lo"]="$lo"
  OPT_RSHORT["$lo"]="$sh"
  [ "$sh" != "-" ] && OPT_SHORT["-$sh"]="$lo"
  OPT_TAKE["$lo"]="$take"
  OPT_VAR["$lo"]="$var"
  OPT_DESC["$lo"]="$desc"
}

def_common_opts() {
  def_opt dry-run  - 0 - "只打印将要执行的动作，不产生实际改动"
  def_opt yes      y 0 - "非交互模式，所有确认按 yes 处理"
  def_opt verbose  - 0 - "输出调试信息"
  def_opt no-color - 0 - "关闭彩色输出"
  def_opt color    - 0 - "强制开启彩色输出"
  def_opt help     h 0 - "显示本帮助"
  def_opt version  - 0 - "显示版本号"
}

usage() {
  local lo sh take desc left
  printf '%s%s%s v%s\n\n' "$c_bold" "$SCRIPT_NAME" "$c_reset" "$SCRIPT_VERSION"
  printf '用法: %s %s\n\n' "$SCRIPT_NAME" "$USAGE_LINE"
  printf '选项:\n'
  for lo in ${OPT_ORDER[@]+"${OPT_ORDER[@]}"}; do
    sh="${OPT_RSHORT[$lo]:--}"; take="${OPT_TAKE[$lo]}"; desc="${OPT_DESC[$lo]}"
    if [ "$sh" != "-" ]; then
      if [ "$take" = "1" ]; then left="  -${sh} <值>, --${lo}=<值>"
      else left="  -${sh}, --${lo}"; fi
    else
      if [ "$take" = "1" ]; then left="      --${lo}=<值>"
      else left="      --${lo}"; fi
    fi
    printf '%-40s %s\n' "$left" "$desc"
  done
  [ -n "$USAGE_NOTE" ] && printf '\n%s\n' "$USAGE_NOTE"
}

# 阶段一：把 -x / -xVALUE / --long value / --long=value 统一成 "名字<TAB>值"
normalize_args() {
  NORM_ARGS=()
  local i=1 n=$# a name val lo ch rest
  while [ "$i" -le "$n" ]; do
    a="${!i}"
    case "$a" in
      --*=*)
        name="${a%%=*}"; val="${a#*=}"
        NORM_ARGS+=("$name"$'\t'"$val")
        ;;
      --*)
        name="$a"; lo="${OPT_LONG[$name]:-}"
        if [ -z "$lo" ]; then err "未知选项: $name（用 --help 查看可用选项）"; return 2; fi
        if [ "${OPT_TAKE[$lo]}" = "1" ]; then
          i=$((i+1))
          if [ "$i" -gt "$n" ]; then err "选项 $name 需要一个参数"; return 2; fi
          val="${!i}"
        else val=""; fi
        NORM_ARGS+=("$name"$'\t'"$val")
        ;;
      -?*)
        ch="${a:1:1}"; rest="${a:2}"
        lo="${OPT_SHORT["-$ch"]:-}"
        if [ -z "$lo" ]; then
          err "未知选项: -$ch"
          err "提示：跨脚本串联请用长选项（短选项在各脚本里含义不同）"
          return 2
        fi
        if [ "${OPT_TAKE[$lo]}" = "1" ]; then
          if [ -n "$rest" ]; then val="$rest"
          else
            i=$((i+1))
            if [ "$i" -gt "$n" ]; then err "选项 -$ch 需要一个参数"; return 2; fi
            val="${!i}"
          fi
        else val=""; fi
        NORM_ARGS+=("--$lo"$'\t'"$val")
        ;;
      *)
        POSITIONAL+=("$a")
        ;;
    esac
    i=$((i+1))
  done
  return 0
}

apply_args() {
  local t name val lo var
  for t in ${NORM_ARGS[@]+"${NORM_ARGS[@]}"}; do
    name="${t%%$'\t'*}"; val="${t#*$'\t'}"
    lo="${OPT_LONG[$name]:-}"
    [ -n "$lo" ] || { err "未知选项: $name"; return 2; }
    case "$lo" in
      help)     usage; exit 0 ;;
      version)  printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      no-color) USE_COLOR=0; init_colors ;;
      color)    USE_COLOR=1; init_colors ;;
      dry-run)  DRY_RUN=1 ;;
      yes)      ASSUME_YES=1 ;;
      verbose)  VERBOSE=1 ;;
      *)
        var="${OPT_VAR[$lo]:-}"
        if [ -n "$var" ] && [ "$var" != "-" ]; then
          printf -v "$var" '%s' "$val"
          OPT_SET["$lo"]=1
        fi
        ;;
    esac
  done
  return 0
}

parse_cli() {
  normalize_args "$@" || return $?
  apply_args || return $?
  if [ ${#POSITIONAL[@]} -gt 0 ]; then
    err "不接受位置参数: ${POSITIONAL[0]}（本脚本全部用选项传参）"
    return 2
  fi
  return 0
}

# ---------- env 文件 ----------
declare -A ENVF
load_env_file() {
  local path="$1" line key value
  [ -f "$path" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in \#*|"") continue ;; esac
    line="${line#"${line%%[![:space:]]*}"}"
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    value="${value%"${value##*[![:space:]]}"}"
    # 引号包裹：只取引号内的内容，引号之后一律视为行内注释
    # 无引号：剥掉 " # 说明" / "\t# 说明"
    case "$value" in
      \"*)    value="${value#\"}"; value="${value%%\"*}" ;;
      \'*)    value="${value#\'}"; value="${value%%\'*}" ;;
      *" #"*)   value="${value%% #*}" ;;
      *$'\t'#*) value="${value%%$'\t'#*}" ;;
    esac
    value="${value%"${value##*[![:space:]]}"}"
    ENVF["$key"]="$value"
  done < "$path"
  return 0
}

# cfg_get <长选项名> <环境变量名> <env文件键> <默认值>
cfg_get() {
  local lo="$1" en="$2" ek="$3" def="$4" var v=""
  # "-" 表示"无对应来源"，必须归一化为空串：
  # 否则 ${!en} 会变成对名字为 "-" 的变量做间接展开，bash 会给出垃圾值
  case "$en" in ""|-) en="" ;; esac
  case "$ek" in ""|-) ek="" ;; esac
  var="${OPT_VAR[$lo]:-}"
  if [ -n "$var" ] && [ "$var" != "-" ] && [ "${OPT_SET[$lo]:-0}" = "1" ]; then v="${!var:-}"; fi
  if [ -z "$v" ] && [ -n "$en" ] && [ -n "${!en+x}" ]; then v="${!en}"; fi
  if [ -z "$v" ] && [ -n "$ek" ] && [ -n "${ENVF[$ek]:-}" ]; then v="${ENVF[$ek]}"; fi
  [ -z "$v" ] && v="$def"
  printf '%s' "$v"
}

cfg_src() {
  local lo="$1" en="$2" ek="$3" var
  case "$en" in ""|-) en="" ;; esac
  case "$ek" in ""|-) ek="" ;; esac
  var="${OPT_VAR[$lo]:-}"
  if [ -n "$var" ] && [ "$var" != "-" ] && [ "${OPT_SET[$lo]:-0}" = "1" ]; then printf '命令行'; return; fi
  if [ -n "$en" ] && [ -n "${!en+x}" ] && [ -n "${!en}" ]; then printf '环境变量'; return; fi
  if [ -n "$ek" ] && [ -n "${ENVF[$ek]:-}" ]; then printf 'env文件'; return; fi
  printf '默认值'
}

# ---------- 缺失参数：一次性列全 ----------
miss() {
  # miss <长选项/环境变量> [说明] —— 两列对齐，缺几项一眼看全
  local opt="$1" tip="${2:-}"
  if [ -n "$tip" ]; then
    MISSING+=("$(printf '%-38s %s' "$opt" "$tip")")
  else
    MISSING+=("$opt")
  fi
}
check_missing() {
  [ ${#MISSING[@]} -gt 0 ] || return 0
  local m
  err "以下必填参数缺失（共 ${#MISSING[@]} 项）："
  for m in ${MISSING[@]+"${MISSING[@]}"}; do
    printf '  %s· %s%s\n' "$c_red" "$m" "$c_reset" >&2
  done
  return 1
}

ask() {
  local tip="$1" sec="${2:-no}" ans=""
  [ -t 0 ] || return 1
  [ "$ASSUME_YES" -eq 1 ] && return 1
  printf '%s%s%s ' "$c_yellow" "$tip" "$c_reset" >&2
  if [ "$sec" = "yes" ]; then read -r -s ans || true; printf '\n' >&2
  else read -r ans || true; fi
  ans="${ans#"${ans%%[![:space:]]*}"}"
  ans="${ans%"${ans##*[![:space:]]}"}"
  [ -n "$ans" ] || return 1
  printf '%s' "$ans"
}

confirm() {
  local tip="${1:-确认继续?}" ans
  [ "$ASSUME_YES" -eq 1 ] && return 0
  [ -t 0 ] || { warn "非交互且未给 --yes，按继续处理"; return 0; }
  printf '%s%s%s [y/N] ' "$c_yellow" "$tip" "$c_reset" >&2
  read -r ans || true
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

normalize_bool() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on)  printf 'true' ;;
    0|false|no|off) printf 'false' ;;
    *)              printf '%s' "${1:-}" ;;
  esac
}

normalize_yesno() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on)  printf 'yes' ;;
    0|false|no|off) printf 'no' ;;
    *)              printf '%s' "${1:-}" ;;
  esac
}

USAGE_LINE="${USAGE_LINE:-[选项]}"
USAGE_NOTE="${USAGE_NOTE:-}"
# ------------------------------ 公共区段结束 ----------------------------------

# ==============================================================================
#  ssh.sh 自身部分
# ==============================================================================

USAGE_LINE="[--env <文件|URL>] [--port <端口>] [--pubkey <公钥>] [选项]"
USAGE_NOTE="环境变量（优先级低于命令行、高于 env 文件与默认值）:
  VPS_SSH_ENV  VPS_SSH_PORT  VPS_SSH_ROOT_LOGIN  VPS_SSH_PASSWORD_AUTH
  VPS_SSH_EMPTY_PASSWORDS  VPS_SSH_MAX_AUTH_TRIES  VPS_SSH_PUBKEY_AUTH
  VPS_SSH_PUBKEY  VPS_SSH_CONFIG  VPS_SSH_CHOICE

env 文件键（默认 ssh.env）:
  ssh_port  ssh_permit_root_login  ssh_password_auth  ssh_permit_empty_passwords
  ssh_max_auth_tries  ssh_pubkey_auth  pubkey_<名称>

示例:
  $SCRIPT_NAME --port=2222 --root-login=no --password-auth=no --pubkey=\"\$(cat ~/.ssh/id_ed25519.pub)\"
  $SCRIPT_NAME --env=ssh.env --choice=1 --dry-run
  $SCRIPT_NAME --port=2222 --choice=2 --skip-restart

说明:
  · 取值优先级：命令行 > VPS_* 环境变量 > env 文件 > 内置默认
  · 跨脚本串联务必用长选项：ssh 的 -R 是 --root-login，start.sh 的 -R 是 --prefix
  · 改端口前先确认新端口已在防火墙放行，否则可能把自己锁在门外"

def_opt env            f 1 A_ENV       "env 文件路径或 URL（默认 ssh.env）"
def_opt port           P 1 A_PORT      "SSH 端口（默认 22）"
def_opt root-login     R 1 A_ROOTLOGIN "PermitRootLogin yes|no（默认 yes）"
def_opt password-auth  A 1 A_PASSAUTH  "PasswordAuthentication yes|no（默认 yes）"
def_opt empty-passwords E 1 A_EMPTYPASS "PermitEmptyPasswords yes|no（默认 no）"
def_opt max-auth-tries M 1 A_MAXTRIES  "MaxAuthTries（默认 3）"
def_opt pubkey-auth    U 1 A_PUBAUTH   "PubkeyAuthentication yes|no（默认 yes）"
def_opt pubkey         K 1 A_PUBKEY    "直接给公钥整行内容"
def_opt pubkey-file    - 1 A_PUBFILE   "从文件读取公钥（如 ~/.ssh/id_ed25519.pub）"
def_opt pubkey-name    N 1 A_PUBNAME   "从 env 文件读取 pubkey_<名称>"
def_opt config         - 1 A_CONFIG    "sshd_config 路径（默认 /etc/ssh/sshd_config）"
def_opt choice         C 1 A_CHOICE    "操作：1 改全部并重启 / 2 仅加公钥 / 0 退出"
def_opt skip-restart   - 0 A_SKIPRESTART "不重启 SSH 服务（配合 --choice=1）"
def_common_opts

parse_cli "$@" || exit $?

# ---------- 基础检查 ----------
if [ "$(id -u)" != "0" ] && [ "$DRY_RUN" -eq 0 ]; then
  die "请以 root 用户运行（或用 --dry-run 先看将要执行的动作）"
fi

# ---------- 加载 env ----------
env_file="$(cfg_get env VPS_SSH_ENV - "ssh.env")"
env_source="<未加载>"
if is_url "$env_file"; then
  step "从 URL 下载 env: $env_file"
  download "$env_file" "ssh.env" || die "env 下载失败: $env_file"
  load_env_file "ssh.env" && env_source="URL"
elif [ -f "$env_file" ]; then
  load_env_file "$env_file" && env_source="$env_file"
else
  warn "未找到 env 文件: $env_file —— 改用命令行 / 环境变量 / 默认值"
fi

# ---------- 解析取值 ----------
ssh_config="$(cfg_get config VPS_SSH_CONFIG ssh_config "/etc/ssh/sshd_config")"
port="$(cfg_get port           VPS_SSH_PORT              ssh_port                    "22")"
root_login="$(cfg_get root-login     VPS_SSH_ROOT_LOGIN      ssh_permit_root_login       "yes")"
pass_auth="$(cfg_get password-auth   VPS_SSH_PASSWORD_AUTH   ssh_password_auth           "yes")"
empty_pass="$(cfg_get empty-passwords VPS_SSH_EMPTY_PASSWORDS ssh_permit_empty_passwords "no")"
max_tries="$(cfg_get max-auth-tries  VPS_SSH_MAX_AUTH_TRIES  ssh_max_auth_tries          "3")"
pubkey_auth="$(cfg_get pubkey-auth   VPS_SSH_PUBKEY_AUTH     ssh_pubkey_auth             "yes")"
public_key="$(cfg_get pubkey         VPS_SSH_PUBKEY          -                           "")"
pubkey_name="$(cfg_get pubkey-name   -                       -                           "")"
pubkey_file="$(cfg_get pubkey-file   -                       -                           "")"
choice="$(cfg_get choice             VPS_SSH_CHOICE          ssh_choice                  "")"

authorized_keys="/root/.ssh/authorized_keys"

# 公钥来源：--pubkey > --pubkey-file > --pubkey-name(env) > 交互
if [ -z "$public_key" ] && [ -n "$pubkey_file" ]; then
  if [ -f "$pubkey_file" ]; then
    public_key="$(head -n 1 "$pubkey_file")" || public_key=""
    [ -n "$public_key" ] && log "已从文件读取公钥: $pubkey_file"
  else
    err "--pubkey-file 文件不存在: $pubkey_file"
    exit 2
  fi
fi
if [ -z "$public_key" ] && [ -n "$pubkey_name" ]; then
  public_key="${ENVF[pubkey_${pubkey_name}]:-}"
  [ -z "$public_key" ] && warn "env 里没有 pubkey_${pubkey_name} 这个键"
fi

# 规范化
root_login="$(normalize_yesno "$root_login")"
pass_auth="$(normalize_yesno "$pass_auth")"
empty_pass="$(normalize_yesno "$empty_pass")"
pubkey_auth="$(normalize_yesno "$pubkey_auth")"

# ---------- 校验 ----------
if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
  err "--port 无效: $port（需为 1-65535 的整数）"
  exit 2
fi
if ! [[ "$max_tries" =~ ^[0-9]+$ ]]; then
  err "--max-auth-tries 无效: $max_tries（需为正整数）"
  exit 2
fi
for _p in "root-login:$root_login" "password-auth:$pass_auth" "empty-passwords:$empty_pass" "pubkey-auth:$pubkey_auth"; do
  case "${_p#*:}" in
    yes|no) ;;
    *) err "--${_p%%:*} 无效: ${_p#*:}（只支持 yes / no）"; exit 2 ;;
  esac
done
[ -f "$ssh_config" ] || { err "找不到 sshd_config: $ssh_config（可用 --config 指定）"; exit 2; }

# ---------- 展示当前配置 ----------
section "当前 SSH 配置（$ssh_config）"
show_item() {
  local item="$1" value
  value="$(grep -iE "^[[:space:]]*${item}[[:space:]]+" "$ssh_config" 2>/dev/null | tail -n1 | awk '{print $2}')"
  if [ -n "$value" ]; then kv "$item" "$value"
  else kv "$item" "<未设置>"; fi
}
for _i in Port PermitRootLogin PasswordAuthentication PermitEmptyPasswords MaxAuthTries PubkeyAuthentication; do
  show_item "$_i"
done

section "将要写入的配置（来源已标注）"
kv3 "port"             "$port"        "$(cfg_src port VPS_SSH_PORT ssh_port)"
kv3 "root-login"       "$root_login"  "$(cfg_src root-login VPS_SSH_ROOT_LOGIN ssh_permit_root_login)"
kv3 "password-auth"    "$pass_auth"   "$(cfg_src password-auth VPS_SSH_PASSWORD_AUTH ssh_password_auth)"
kv3 "empty-passwords"  "$empty_pass"  "$(cfg_src empty-passwords VPS_SSH_EMPTY_PASSWORDS ssh_permit_empty_passwords)"
kv3 "max-auth-tries"   "$max_tries"   "$(cfg_src max-auth-tries VPS_SSH_MAX_AUTH_TRIES ssh_max_auth_tries)"
kv3 "pubkey-auth"      "$pubkey_auth" "$(cfg_src pubkey-auth VPS_SSH_PUBKEY_AUTH ssh_pubkey_auth)"
kv3 "pubkey"           "$public_key"  "$(cfg_src pubkey VPS_SSH_PUBKEY -)"
[ "$env_source" != "<未加载>" ] && kv3 "env" "$env_file" "$env_source"

# ---------- 动作 ----------
modify_config() {
  local key="$1" value="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] ${key} ${value}"
    return 0
  fi
  cp -a "$ssh_config" "${ssh_config}.bak.$(date +%s)" 2>/dev/null || true
  sed -i "/^[#[:space:]]*${key}[[:space:]]/Id" "$ssh_config"
  printf '%s %s\n' "$key" "$value" >> "$ssh_config"
  ok "已写入 ${key} = ${value}"
}

add_public_key() {
  local key="$1"
  if [ -z "$key" ]; then warn "公钥为空，跳过添加"; return 0; fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] 追加公钥到 ${authorized_keys}: $(mask "$key")"
    return 0
  fi
  mkdir -p /root/.ssh; chmod 700 /root/.ssh
  touch "$authorized_keys"; chmod 600 "$authorized_keys"; chown root:root "$authorized_keys" 2>/dev/null || true
  if grep -qxF -- "$key" "$authorized_keys" 2>/dev/null; then
    ok "公钥已存在，跳过"
  else
    printf '%s\n' "$key" >> "$authorized_keys"
    ok "已添加公钥到 $authorized_keys"
  fi
}

restart_ssh() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] 校验配置并重启 SSH 服务"
    return 0
  fi
  step "校验 SSH 配置..."
  if have_cmd sshd; then
    sshd -t 2>/dev/null || die "sshd 配置校验失败，未重启。请检查 $ssh_config（备份在同目录 .bak.*）"
    ok "配置校验通过"
  else
    warn "找不到 sshd 命令，跳过语法校验"
  fi
  step "重启 SSH 服务..."
  if have_cmd systemctl; then
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || die "重启 SSH 失败，请手动处理"
  elif have_cmd service; then
    service sshd restart 2>/dev/null || service ssh restart 2>/dev/null || die "重启 SSH 失败，请手动处理"
  else
    warn "找不到 systemctl/service，请手动重启 SSH 服务"
    return 0
  fi
  ok "SSH 服务已重启"
}

apply_all() {
  step "写入全部配置..."
  modify_config "Port"                  "$port"
  modify_config "PermitRootLogin"       "$root_login"
  modify_config "PasswordAuthentication" "$pass_auth"
  modify_config "PermitEmptyPasswords"  "$empty_pass"
  modify_config "MaxAuthTries"          "$max_tries"
  modify_config "PubkeyAuthentication"  "$pubkey_auth"
  add_public_key "$public_key"
  if [ "${OPT_SET[skip-restart]:-0}" = "1" ]; then
    warn "已给 --skip-restart，不重启 SSH 服务"
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] 校验配置并重启 SSH 服务"
  else
    restart_ssh
  fi
}

# ---------- 选择操作 ----------
if [ -z "$choice" ]; then
  if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    warn "未给 --choice，进入交互选择"
    echo "  1. 修改全部（写入 sshd_config 并重启 ssh）"
    echo "  2. 仅添加公钥"
    echo "  0. 退出"
    choice="$(ask "请输入 [0/1/2]" || true)"
  else
    err "未给 --choice，且当前非交互（可加 --yes 或显式 --choice）"
    exit 2
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then warn "dry-run：以下操作不会真正写入磁盘" ; fi

case "$choice" in
  1) apply_all ;;
  2) add_public_key "$public_key" ;;
  0) warn "用户选择退出"; exit 0 ;;
  "") err "未选择操作"; exit 2 ;;
  *)  err "无效的 --choice: $choice（只支持 0 / 1 / 2）"; exit 2 ;;
esac

ok "ssh.sh 执行完毕"
exit 0
