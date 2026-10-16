#!/usr/bin/env bash
# ==============================================================================
#  nezha.sh — 哪吒探针 Agent 安装（独立脚本）
#  版本 : v2.1
#  规范 : sh/UNIFIED v2（与 ddns.sh / ssh.sh / env.sh / start.sh / proxy.sh 共用）
#
#  由 start.sh v2.1 拆分而来：start.sh --choice=5 现在以长选项透传调用本脚本。
#
#  示例:
#    ./nezha.sh --nezha-ip=1.2.3.4 --nezha-port=8008 --nezha-key=NZ_xxx
#    ./nezha.sh --env=vps.env
#    ./nezha.sh --env=vps.env --dry-run
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
#  nezha.sh 自身部分 —— 哪吒探针 Agent 安装
# ==============================================================================

USAGE_LINE="--nezha-ip <ip> --nezha-port <port> --nezha-key <secret> [选项]"
USAGE_NOTE="必填（缺失一次性列全，exit 2）:
  --nezha-ip    哪吒面板 IP 或域名      (VPS_NEZHA_IP / env: nezha_panel_ip)
  --nezha-port  哪吒面板端口            (VPS_NEZHA_PORT / env: nezha_panel_port)
  --nezha-key   哪吒 Agent Secret       (VPS_NEZHA_KEY / env: nezha_agent_key)

可选:
  --nezha-tls   true|false（默认 false）(VPS_NEZHA_TLS / env: nezha_panel_tls)
  --nz-uuid     固定 UUID（不给由面板分配）(VPS_NZ_UUID)
  --env <文件>  env 文件路径（默认 vps.env，存在才加载；键名同 start.sh --save-env 输出）

示例:
  $SCRIPT_NAME --nezha-ip=1.2.3.4 --nezha-port=8008 --nezha-key=NZ_xxx
  $SCRIPT_NAME --env=vps.env
  $SCRIPT_NAME --env=vps.env --dry-run

说明:
  · 安装前会检测 unzip（官方脚本解压 agent 需要），缺失则自动安装；curl/wget 由下载函数处理
  · 内部下载官方 nezhahq/scripts agent/install.sh，以 env 变量方式传给安装器（不再 eval 拼接）
  · 取值优先级：命令行 > VPS_* 环境变量 > env 文件 > 默认"

def_opt nezha-ip   - 1 A_NZIP   "哪吒面板 IP 或域名（必填）"
def_opt nezha-port - 1 A_NZPORT "哪吒面板端口（必填）"
def_opt nezha-tls  - 1 A_NZTLS  "是否 TLS true|false（默认 false）"
def_opt nezha-key  - 1 A_NZKEY  "哪吒 Agent Secret（必填）"
def_opt nz-uuid    - 1 A_NZUUID "哪吒 Agent UUID（可选）"
def_opt env        f 1 A_ENV    "env 文件路径（默认 vps.env，存在才加载）"
def_common_opts

parse_cli "$@" || exit $?

# ---------- env 文件 ----------
env_file="$(cfg_get env VPS_ENV - "vps.env")"
if [ -f "$env_file" ]; then
  load_env_file "$env_file" && ok "已加载 env 文件: ${env_file}"
elif [ "$env_file" != "vps.env" ]; then
  die "env 文件不存在: $env_file"
fi

# ---------- 解析取值 ----------
nezha_ip="$(cfg_get nezha-ip   VPS_NEZHA_IP   nezha_panel_ip   "")"
nezha_port="$(cfg_get nezha-port VPS_NEZHA_PORT nezha_panel_port "")"
nezha_tls="$(cfg_get nezha-tls  VPS_NEZHA_TLS  nezha_panel_tls  "false")"
nezha_key="$(cfg_get nezha-key  VPS_NEZHA_KEY  nezha_agent_key  "")"
nz_uuid="$(cfg_get nz-uuid VPS_NZ_UUID - "")"
nezha_tls="$(normalize_bool "$nezha_tls")"

# ---------- 摘要 ----------
section "参数摘要（来源已标注，敏感值已脱敏）"
kv3 "nezha-ip"   "$nezha_ip"   "$(cfg_src nezha-ip VPS_NEZHA_IP nezha_panel_ip)"
kv3 "nezha-port" "$nezha_port" "$(cfg_src nezha-port VPS_NEZHA_PORT nezha_panel_port)"
kv3 "nezha-tls"  "$nezha_tls"  "$(cfg_src nezha-tls VPS_NEZHA_TLS nezha_panel_tls)"
kv3 "nezha-key"  "$nezha_key"  "$(cfg_src nezha-key VPS_NEZHA_KEY nezha_agent_key)" yes
kv3 "nz-uuid"    "$nz_uuid"    "$(cfg_src nz-uuid VPS_NZ_UUID -)"

# ---------- 校验 ----------
MISSING=()
[ -z "$nezha_ip" ]   && miss "--nezha-ip / VPS_NEZHA_IP"     "哪吒面板 IP 或域名"
[ -z "$nezha_port" ] && miss "--nezha-port / VPS_NEZHA_PORT" "哪吒面板端口"
[ -z "$nezha_key" ]  && miss "--nezha-key / VPS_NEZHA_KEY"   "哪吒 Agent Secret"
check_missing || exit 2

if [[ ! "$nezha_port" =~ ^[0-9]+$ ]]; then
  err "--nezha-port 必须是纯数字，当前为: $nezha_port"
  exit 2
fi

# ---------- 安装 ----------
do_install() {
  step "安装哪吒探针 Agent..."
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] 检查依赖 unzip（缺失则自动安装）"
    log "  [dry-run] 下载官方 agent/install.sh"
    log "  [dry-run] NZ_SERVER=${nezha_ip}:${nezha_port} NZ_TLS=${nezha_tls} NZ_CLIENT_SECRET=$(mask "$nezha_key")${nz_uuid:+ NZ_UUID=$nz_uuid} bash install.sh"
    return 0
  fi
  local rc
  ensure_unzip
  local t
  t="$(mktemp)"
  download "https://raw.githubusercontent.com/nezhahq/scripts/main/agent/install.sh" "$t" \
    || { rm -f "$t"; die "下载哪吒安装脚本失败"; }
  # 下载"成功"但内容为空也要拦掉（curl 退出码为 0 却什么都没写的情况）
  [ -s "$t" ] || { rm -f "$t"; die "下载的安装脚本内容为空，请检查网络"; }
  chmod +x "$t"
  # 以 env 变量方式传参，替代旧版 eval 拼接（值里出现空格/特殊字符也安全）
  local -a env_args=(env "NZ_SERVER=${nezha_ip}:${nezha_port}" "NZ_TLS=${nezha_tls}" "NZ_CLIENT_SECRET=${nezha_key}")
  [ -n "$nz_uuid" ] && env_args+=("NZ_UUID=${nz_uuid}")
  # 注意：local rc 必须在下面两句【之前】声明 —— 单独一行 local 会把 $? 重置为 0
  if [ -n "$sudo_cmd" ]; then
    sudo "${env_args[@]}" bash "$t"
  else
    "${env_args[@]}" bash "$t"
  fi
  rc=$?
  rm -f "$t"
  [ "$rc" -eq 0 ] || { err "哪吒安装脚本返回非零（rc=${rc}）"; return "$rc"; }
  ok "哪吒探针安装完成"
}

do_install
rc=$?
if [ "$rc" -eq 0 ]; then
  line
  ok "nezha.sh 执行完毕"
  exit 0
else
  err "nezha.sh 执行失败（rc=${rc}）"
  exit "$rc"
fi
