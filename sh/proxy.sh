#!/usr/bin/env bash
# ==============================================================================
#  proxy.sh — soga 代理安装与配置修改（独立脚本）
#  版本 : v2.1
#  规范 : sh/UNIFIED v2（与 ddns.sh / ssh.sh / env.sh / start.sh / nezha.sh 共用）
#
#  由 start.sh v2.1 拆分而来：start.sh --choice=3/4/6 现在以长选项透传调用本脚本。
#
#  两条硬规则：
#    1. soga 默认安装 2.13.4，可用 --soga-version 更换
#    2. 配置文件修改（--action=config / both）的四个对接参数【必须显式传入】，
#       空白（含纯空格）一律报错退出，绝不拿空值写配置
#
#  示例:
#    ./proxy.sh --action=install
#    ./proxy.sh --action=install --soga-version=2.14.0
#    ./proxy.sh --action=config --ss-id=3 --vmess-id=4 --webapi-url=https://a --webapi-key=K
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
SCRIPT_VERSION="2.1.0"

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

# 显示列宽与补齐（不依赖 locale）
# bash 的 printf 按【字节数】补齐，而 CJK 占 2 列、… 占 1 列 ⇒ 直接把值交给 %-Ns 会错位。
# 这里按 UTF-8 首字节自行分类：ASCII=1 列、…=1 列、2 字节字符=1 列、3/4 字节=2 列。
KW_KEY=18
KW_VAL=36

disp_width() {
  local s="$1" i=0 w=0 bytes rest
  local LC_ALL=C
  bytes=${#s}
  while [ "$i" -lt "$bytes" ]; do
    rest="${s:i}"
    case "$rest" in
      $'\xE2\x80\xA6'*)   w=$((w + 1)); i=$((i + 3)) ;;   # … 省略号
      [$'\xE0'-$'\xEF']*)  w=$((w + 2)); i=$((i + 3)) ;;   # 3 字节（CJK 等）
      [$'\xF0'-$'\xF7']*)  w=$((w + 2)); i=$((i + 4)) ;;   # 4 字节
      [$'\xC0'-$'\xDF']*)  w=$((w + 1)); i=$((i + 2)) ;;   # 2 字节（·、° 等按窄算）
      *)                    w=$((w + 1)); i=$((i + 1)) ;;   # ASCII
    esac
  done
  printf '%s' "$w"
}

pad_disp() {
  # pad_disp <字符串> <目标列宽>：不足补空格；超长按字符边界截断并加 …
  local s="$1" n="$2" i=0 w=0 step=1 cw=1 out="" bytes rest last_i=-1 last_cw=1
  local LC_ALL=C
  bytes=${#s}
  while [ "$i" -lt "$bytes" ]; do
    rest="${s:i}"
    case "$rest" in
      $'\xE2\x80\xA6'*)   cw=1; step=3 ;;
      [$'\xE0'-$'\xEF']*)  cw=2; step=3 ;;
      [$'\xF0'-$'\xF7']*)  cw=2; step=4 ;;
      [$'\xC0'-$'\xDF']*)  cw=1; step=2 ;;
      *)                    cw=1; step=1 ;;
    esac
    if [ $((w + cw)) -gt "$n" ]; then
      # 截断：为 … 腾出 1 列（已占满 n 列时去掉最后追加的那个字符），补足到 n 列
      if [ "$w" -ge "$n" ] && [ "$last_i" -ge 0 ]; then
        out="${out:0:last_i}"
        w=$((w - last_cw))
      fi
      printf '%s…%*s' "$out" "$((n - w - 1))" ""
      return 0
    fi
    last_i=${#out}
    last_cw=$cw
    out="${out}${s:i:step}"
    w=$((w + cw))
    i=$((i + step))
  done
  printf '%s%*s' "$out" "$((n - w))" ""
}

kv() {
  local k="$1" v="$2" sec="${3:-no}"
  [ "$sec" = "yes" ] && [ -n "$v" ] && v="$(mask "$v")"
  printf '  %s%s%s : %s%s%s\n' \
    "$c_cyan" "$(pad_disp "$k" "$KW_KEY")" "$c_reset" "$c_orange" "${v:-<未设置>}" "$c_reset"
}

kv3() {
  local k="$1" v="$2" s="${3:-}" sec="${4:-no}"
  [ "$sec" = "yes" ] && [ -n "$v" ] && v="$(mask "$v")"
  printf '  %s%s%s : %s%s%s %s(%s)%s\n' \
    "$c_cyan" "$(pad_disp "$k" "$KW_KEY")" "$c_reset" \
    "$c_orange" "$(pad_disp "${v:-<未设置>}" "$KW_VAL")" "$c_reset" \
    "$c_gray" "$s" "$c_reset"
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
#  proxy.sh 自身部分 —— soga 安装 / 配置修改
# ==============================================================================

USAGE_LINE="--action install|config|both [--soga-version <版本>] [对接参数] [选项]"
USAGE_NOTE="动作 --action:
  install  只安装 soga 并创建 ss / vmess 实例（不需要对接参数）
  config   只修改配置文件并启动（对接参数必填）
  both     先装后配（默认）

对接参数（--action=config / both 时必填；空白或纯空格一律报错，exit 2）:
  --ss-id <id>        Shadowsocks 节点 ID     (VPS_SS_ID)
  --vmess-id <id>     Vmess 节点 ID           (VPS_VMESS_ID)
  --webapi-url <url>  v2board webapi 地址     (VPS_WEBAPI_URL / env: v2board_webapi_url)
  --webapi-key <key>  v2board webapi key      (VPS_WEBAPI_KEY / env: v2board_webapi_key)

soga 版本:
  默认 2.13.4，用 --soga-version 更换（如 --soga-version=2.14.0）

env 文件:
  默认加载当前目录 vps.env（存在才加载，--env 可指定路径；非默认路径不存在则报错）

示例:
  $SCRIPT_NAME --action=install
  $SCRIPT_NAME --action=install --soga-version=2.14.0
  $SCRIPT_NAME --action=config --ss-id=3 --vmess-id=4 --webapi-url=https://a --webapi-key=K
  $SCRIPT_NAME --env=vps.env --dry-run

说明:
  · 配置模板从仓库 config/soga-ss.conf、config/soga-vmess.conf 下载后替换参数
  · config 完成后自动 soga start + enable（--no-restart 可跳过）"

def_opt action       a 1 A_ACTION    "install | config | both（默认 both）"
def_opt soga-version s 1 A_SOGAVER   "soga 版本号（默认 2.13.4）"
def_opt arch         - 1 A_ARCH      "目标架构 amd64|arm64|arm（默认自动检测）"
def_opt ss-id        S 1 A_SSID      "Shadowsocks 节点 ID（config/both 必填）"
def_opt vmess-id     V 1 A_VMESSID   "Vmess 节点 ID（config/both 必填）"
def_opt webapi-url   - 1 A_WEBURL    "v2board webapi 地址（config/both 必填）"
def_opt webapi-key   - 1 A_WEBKEY    "v2board webapi key（config/both 必填）"
def_opt env          f 1 A_ENV       "env 文件路径（默认 vps.env，存在才加载）"
def_opt no-restart   - 0 A_NORESTART "配置写入后不启动 / 不启用实例"
def_common_opts

parse_cli "$@" || exit $?

REPO_RAW="https://raw.githubusercontent.com/RexLee0929/VPS/main"

# ---------- env 文件 ----------
env_file="$(cfg_get env VPS_ENV - "vps.env")"
if [ -f "$env_file" ]; then
  load_env_file "$env_file" && ok "已加载 env 文件: ${env_file}"
elif [ "$env_file" != "vps.env" ]; then
  die "env 文件不存在: $env_file"
fi

# ---------- 解析取值 ----------
action="$(cfg_get action VPS_SOGA_ACTION - "both")"
soga_version="$(cfg_get soga-version VPS_SOGA_VERSION - "2.13.4")"
arch_opt="$(cfg_get arch - - "")"
ss_node_id="$(cfg_get ss-id VPS_SS_ID - "")"
vmess_node_id="$(cfg_get vmess-id VPS_VMESS_ID - "")"
webapi_url="$(cfg_get webapi-url VPS_WEBAPI_URL v2board_webapi_url "")"
webapi_key="$(cfg_get webapi-key VPS_WEBAPI_KEY v2board_webapi_key "")"

case "$action" in
  install|config|both) ;;
  *) err "无效的 --action: $action（只支持 install / config / both）"; exit 2 ;;
esac

if [[ ! "$soga_version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
  err "--soga-version 格式无效: $soga_version（示例：2.13.4 / 2.14.0）"
  exit 2
fi

if [ -n "$arch_opt" ]; then
  case "$arch_opt" in
    amd64|arm64|arm) arch="$arch_opt" ;;
    *) err "无效的 --arch: $arch_opt（amd64 / arm64 / arm）"; exit 2 ;;
  esac
else
  case "$(uname -m)" in
    x86_64|amd64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l|armv7)  arch="arm" ;;
    *)             arch="amd64"; warn "无法识别架构 $(uname -m)，按 amd64 处理" ;;
  esac
fi

if [ -w /usr/bin ] || [ "$(id -u)" -eq 0 ]; then sudo_cmd=""; else sudo_cmd="sudo"; fi

# is_blank：空白或纯空格都算空（配置参数的硬校验用）
is_blank() { local s; s="$(printf '%s' "$1" | tr -d '[:space:]')"; [ -z "$s" ]; }

# ---------- 摘要 ----------
section "参数摘要（来源已标注，敏感值已脱敏）"
kv3 "action"       "$action"        "$(cfg_src action VPS_SOGA_ACTION -)"
kv3 "soga-version" "$soga_version"  "$(cfg_src soga-version VPS_SOGA_VERSION -)"
kv3 "arch"         "$arch"          "$(cfg_src arch - -)"
kv3 "ss-id"        "$ss_node_id"    "$(cfg_src ss-id VPS_SS_ID -)"
kv3 "vmess-id"     "$vmess_node_id" "$(cfg_src vmess-id VPS_VMESS_ID -)"
kv3 "webapi-url"   "$webapi_url"    "$(cfg_src webapi-url VPS_WEBAPI_URL v2board_webapi_url)"
kv3 "webapi-key"   "$webapi_key"    "$(cfg_src webapi-key VPS_WEBAPI_KEY v2board_webapi_key)" yes

# ---------- 校验：config / both 必填，空白报错 ----------
if [ "$action" != "install" ]; then
  MISSING=()
  is_blank "$ss_node_id"    && miss "--ss-id / VPS_SS_ID"           "Shadowsocks 节点 ID（必填，空白不允许）"
  is_blank "$vmess_node_id" && miss "--vmess-id / VPS_VMESS_ID"     "Vmess 节点 ID（必填，空白不允许）"
  is_blank "$webapi_url"    && miss "--webapi-url / VPS_WEBAPI_URL" "v2board webapi 地址（必填，空白不允许）"
  is_blank "$webapi_key"    && miss "--webapi-key / VPS_WEBAPI_KEY" "v2board webapi key（必填，空白不允许）"
  if ! check_missing; then
    err "配置文件的修改必须显式传入全部对接参数，空白内容一律报错"
    err "只想安装不配置的话，改用 --action=install"
    exit 2
  fi
fi

# ---------- 动作：install ----------
do_install() {
  step "安装代理（soga ${soga_version}，${arch}）..."
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] 下载 soga-cmd-linux-${arch} -> /usr/bin/soga"
    log "  [dry-run] soga update ${soga_version}"
    log "  [dry-run] soga new ss / soga new vmess"
    return 0
  fi
  local url="https://github.com/vaxilu/soga-cmd/releases/latest/download/soga-cmd-linux-${arch}"
  $sudo_cmd bash -c "curl -fsSL -o /usr/bin/soga '$url' || wget -qO /usr/bin/soga '$url'" \
    || die "下载 soga-cmd 失败: $url"
  $sudo_cmd chmod +x /usr/bin/soga
  [ -s /usr/bin/soga ] || die "下载的 soga 二进制为空，请检查网络"
  log "更新 soga 到 ${soga_version}"
  $sudo_cmd soga update "$soga_version" || warn "soga update 返回非零（可忽略）"
  $sudo_cmd soga new ss    || warn "ss 实例可能已存在"
  $sudo_cmd soga new vmess || warn "vmess 实例可能已存在"
  ok "代理安装完成（soga ${soga_version}）"
}

# ---------- 动作：config ----------
do_config() {
  step "修改 soga 配置文件..."
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] 写入 /etc/soga/ss/soga.conf 与 /etc/soga/vmess/soga.conf"
    log "  [dry-run] node_id=${ss_node_id} / ${vmess_node_id}，webapi_url=${webapi_url}，webapi_key=$(mask "$webapi_key")"
    [ "${OPT_SET[no-restart]:-0}" = "1" ] || log "  [dry-run] soga start ss / vmess 并 enable"
    return 0
  fi
  local t1 t2
  t1="$(mktemp)"; t2="$(mktemp)"
  download "${REPO_RAW}/config/soga-ss.conf"    "$t1" || { rm -f "$t1" "$t2"; die "下载 soga-ss.conf 失败"; }
  download "${REPO_RAW}/config/soga-vmess.conf" "$t2" || { rm -f "$t1" "$t2"; die "下载 soga-vmess.conf 失败"; }
  [ -s "$t1" ] || { rm -f "$t1" "$t2"; die "下载的 soga-ss.conf 内容为空"; }
  [ -s "$t2" ] || { rm -f "$t1" "$t2"; die "下载的 soga-vmess.conf 内容为空"; }
  $sudo_cmd mkdir -p /etc/soga/ss /etc/soga/vmess
  $sudo_cmd mv "$t1" /etc/soga/ss/soga.conf
  $sudo_cmd mv "$t2" /etc/soga/vmess/soga.conf
  $sudo_cmd sed -i "s/node_id=.*/node_id=${ss_node_id}/g"       /etc/soga/ss/soga.conf
  $sudo_cmd sed -i "s|webapi_url=.*|webapi_url=${webapi_url}|g" /etc/soga/ss/soga.conf
  $sudo_cmd sed -i "s/webapi_key=.*/webapi_key=${webapi_key}/g" /etc/soga/ss/soga.conf
  $sudo_cmd sed -i "s/node_id=.*/node_id=${vmess_node_id}/g"    /etc/soga/vmess/soga.conf
  $sudo_cmd sed -i "s|webapi_url=.*|webapi_url=${webapi_url}|g" /etc/soga/vmess/soga.conf
  $sudo_cmd sed -i "s/webapi_key=.*/webapi_key=${webapi_key}/g" /etc/soga/vmess/soga.conf
  if [ "${OPT_SET[no-restart]:-0}" = "1" ]; then
    warn "已给 --no-restart，不启动 / 不启用实例"
  else
    $sudo_cmd soga start ss    || warn "soga start ss 返回非零（可忽略）"
    $sudo_cmd soga start vmess || warn "soga start vmess 返回非零（可忽略）"
    $sudo_cmd soga enable ss    || true
    $sudo_cmd soga enable vmess || true
  fi
  ok "配置已写入"
}

# ---------- 执行 ----------
case "$action" in
  install) do_install ;;
  config)  do_config ;;
  both)    do_install && do_config ;;
esac
rc=$?
if [ "$rc" -eq 0 ]; then
  line
  ok "proxy.sh 执行完毕（action=${action}）"
  exit 0
else
  err "proxy.sh 执行失败（rc=${rc}）"
  exit "$rc"
fi
