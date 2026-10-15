#!/usr/bin/env bash
# ==============================================================================
#  ddns.sh — Cloudflare DDNS 更新脚本
#  版本 : v2.0
#  规范 : sh/UNIFIED v2（与 ssh.sh / env.sh / start.sh 共用同一套写法）
#
#  这次重构要解决的事：
#    · 四个脚本串联执行时短选项互相撞车（-t 在 ddns 是类型、在 env 是 token）
#      → 长选项成为唯一权威接口，短选项只作兼容保留
#    · 参数漏传 → 缺失项一次性列全，并给出可直接复制的补全方式
#    · 取值来源统一为：命令行 > VPS_* 环境变量 > env 文件 > 内置默认
#
#  示例:
#    ./ddns.sh --domain=example.com --prefix=home
#    ./ddns.sh --domain=example.com --record=home.example.com --type=AAAA
#    ./ddns.sh --domain=example.com --prefix=fnos --dry-run
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
#  ddns.sh 自身部分
# ==============================================================================

USAGE_LINE="--domain <域名> (--record <记录名> | --prefix <前缀>) [选项]"
USAGE_NOTE="环境变量（优先级低于命令行、高于默认值）:
  VPS_CF_KEY        Cloudflare API Token
  VPS_CF_EMAIL      Cloudflare 账号邮箱（Token 模式可省略）
  VPS_DDNS_DOMAIN   主域名
  VPS_DDNS_RECORD   完整记录名
  VPS_DDNS_PREFIX   记录前缀
  VPS_DDNS_TYPE     A | AAAA
  VPS_DDNS_PROXY    true | false
  VPS_DDNS_MODE     color | plain | compact

示例:
  $SCRIPT_NAME --domain=example.com --prefix=home
  $SCRIPT_NAME --domain=example.com --record=home.example.com --type=AAAA
  $SCRIPT_NAME --domain=example.com --prefix=fnos --proxy=false --dry-run

说明:
  · --record 优先于 --prefix；两者都不给时，记录名取 --domain 本身（根域名）
  · 跨脚本串联务必用长选项：ddns 的 -t 是 --type，env.sh 的 -t 是 --token"

def_opt key     k 1 A_KEY    "Cloudflare API Token（必填，或使用 VPS_CF_KEY）"
def_opt email   e 1 A_EMAIL  "Cloudflare 账号邮箱（Token 模式可省略）"
def_opt domain  d 1 A_DOMAIN "主域名，如 example.com（必填）"
def_opt record  r 1 A_RECORD "完整记录名，如 home.example.com"
def_opt prefix  - 1 A_PREFIX "记录前缀，与 --domain 组合成完整记录名"
def_opt type    t 1 A_TYPE   "记录类型 A | AAAA（默认 A）"
def_opt proxy   p 1 A_PROXY  "是否走 CF 代理 true | false（默认 false）"
def_opt mode    - 1 A_MODE   "输出模式 color | plain | compact（默认自动）"
def_common_opts

parse_cli "$@" || exit $?

# ---------- 解析取值 ----------
cf_key="$(cfg_get key    VPS_CF_KEY        cf_key        "")"
cf_email="$(cfg_get email VPS_CF_EMAIL     cf_email      "")"
domain="$(cfg_get domain VPS_DDNS_DOMAIN   domain        "")"
record_name="$(cfg_get record VPS_DDNS_RECORD record     "")"
prefix="$(cfg_get prefix VPS_DDNS_PREFIX   record_prefix "")"
record_type="$(cfg_get type VPS_DDNS_TYPE  type          "A")"
cf_proxy="$(cfg_get proxy VPS_DDNS_PROXY   proxy         "false")"
output_mode="$(cfg_get mode VPS_DDNS_MODE  mode          "")"

# 输出模式：未显式指定时，非 TTY 走 plain
if [ -z "$output_mode" ]; then
  if [ -t 1 ]; then output_mode="color"; else output_mode="plain"; fi
fi
case "$output_mode" in
  color|plain|compact) ;;
  *) err "无效的 --mode: $output_mode（只支持 color / plain / compact）"; exit 2 ;;
esac
if [ "$output_mode" = "plain" ] || [ "$output_mode" = "compact" ]; then
  USE_COLOR=0; init_colors
fi

compact() { [ "$output_mode" = "compact" ]; }

# 记录名推导：--record > --prefix + --domain > --domain
if [ -z "$record_name" ]; then
  if [ -n "$prefix" ] && [ -n "$domain" ]; then
    record_name="${prefix}.${domain}"
  elif [ -n "$domain" ]; then
    record_name="$domain"
    [ -n "$prefix" ] || warn "未给 --record 也未给 --prefix，记录名按根域名处理: ${domain}"
  fi
fi

# ---------- 校验（一次列全） ----------
[ -z "$cf_key" ]      && miss "--key / VPS_CF_KEY" "Cloudflare API Token"
[ -z "$domain" ]      && miss "--domain / VPS_DDNS_DOMAIN" "主域名"
[ -z "$record_name" ] && miss "--record 或 --prefix" "解析出的完整记录名为空"

record_type="$(printf '%s' "$record_type" | tr '[:lower:]' '[:upper:]')"
case "$record_type" in
  A|AAAA) ;;
  *) err "无效的 --type: $record_type（只支持 A / AAAA）"; exit 2 ;;
esac

cf_proxy="$(normalize_bool "$cf_proxy")"
case "$cf_proxy" in
  true|false) ;;
  *) err "无效的 --proxy: $cf_proxy（只支持 true / false）"; exit 2 ;;
esac

if [ -n "$cf_email" ] && [[ "$cf_email" != *@* ]]; then
  err "--email 格式可疑: $cf_email"
  exit 2
fi

if ! check_missing; then
  err "补齐后重试；或用 --help 查看全部选项"
  exit 2
fi

# ---------- 头部与参数摘要 ----------
start_time="$(date +"%Y-%m-%d %H:%M:%S")"
if ! compact; then
  echo
  line
  printf '%s%s%s\n' "$c_bold" "  Rex Lee's DDNS Script  v${SCRIPT_VERSION}" "$c_reset"
  printf '%s%s%s\n' "$c_gray" "  Cloudflare DDNS · ${start_time}" "$c_reset"
  line
  section "参数摘要（来源已标注）"
  kv3 "domain"      "$domain"      "$(cfg_src domain VPS_DDNS_DOMAIN domain)"
  kv3 "record"      "$record_name" "$(cfg_src record VPS_DDNS_RECORD record)"
  kv3 "type"        "$record_type" "$(cfg_src type VPS_DDNS_TYPE type)"
  kv3 "proxy"       "$cf_proxy"    "$(cfg_src proxy VPS_DDNS_PROXY proxy)"
  kv3 "key"         "$cf_key"      "$(cfg_src key VPS_CF_KEY cf_key)" yes
  [ -n "$cf_email" ] && kv3 "email" "$cf_email" "$(cfg_src email VPS_CF_EMAIL cf_email)"
fi

# ---------- dry-run ----------
if [ "$DRY_RUN" -eq 1 ]; then
  warn "dry-run：只展示将要执行的操作，不会请求 Cloudflare API"
  section "将要执行"
  log "1. 获取公网 IP（${record_type}）"
  log "2. GET  /zones?name=${domain}          → 取 Zone ID"
  log "3. GET  /dns_records?type=${record_type}&name=${record_name}  → 查现有记录"
  log "4. 存在则 PUT 更新，不存在则 POST 新建（proxied=${cf_proxy}）"
  exit 0
fi

# ---------- 工具函数 ----------
json_get_first() {
  local json="$1" field="$2"
  if have_cmd jq; then
    printf '%s' "$json" | jq -r --arg f "$field" '.result[0][$f] // empty' 2>/dev/null || true
  else
    printf '%s' "$json" | grep -Po "(?<=\"${field}\":\")[^\"]*" 2>/dev/null | head -1 || true
  fi
}

json_success() {
  local json="$1"
  if have_cmd jq; then
    [ "$(printf '%s' "$json" | jq -r '.success // false' 2>/dev/null)" = "true" ]
  else
    [[ "$json" == *'"success":true'* ]]
  fi
}

# ---------- 主流程 ----------
current_ip=""; existing_ip=""; cf_zone_id=""; cf_record_id=""
action="未执行"; result_message=""; fail_reason=""

IP_SERVICES=("https://ip.sb" "https://icanhazip.com" "https://ifconfig.me/ip")

get_public_ip() {
  local flag="-4" svc ip
  [ "$record_type" = "AAAA" ] && flag="-6"
  step "获取公网 IP（${record_type}）..."
  for svc in "${IP_SERVICES[@]}"; do
    ip="$(curl "$flag" -fsS --max-time 10 "$svc" 2>/dev/null | tr -d '[:space:]')" || ip=""
    [ -z "$ip" ] && continue
    if [ "$record_type" = "A" ]; then
      [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { ip=""; continue; }
    else
      [[ "$ip" == *:* ]] || { ip=""; continue; }
    fi
    current_ip="$ip"
    ok "公网 IP: $current_ip（来源 $svc）"
    return 0
  done
  fail_reason="获取公网 IP 失败（已尝试 ${#IP_SERVICES[@]} 个服务）"
  err "$fail_reason"
  exit 1
}

get_zone_id() {
  local json
  step "获取 Cloudflare Zone ID..."
  if ! json="$(curl -fsS --max-time 20 -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer ${cf_key}" \
        -H "Content-Type: application/json" 2>&1)"; then
    fail_reason="请求 Zone ID 失败（网络或凭据问题）"
    err "$fail_reason"
    printf '%s\n' "$json" >&2
    exit 1
  fi
  cf_zone_id="$(json_get_first "$json" "id")"
  if [ -z "$cf_zone_id" ]; then
    fail_reason="获取 Zone ID 失败：域名不在该账号下，或 Token 没有该 zone 的权限"
    err "$fail_reason"
    printf '%s\n' "$json" >&2
    exit 1
  fi
  ok "Zone ID: $cf_zone_id"
}

get_dns_record() {
  local json
  step "查询现有 DNS 记录..."
  if ! json="$(curl -fsS --max-time 20 -X GET \
        "https://api.cloudflare.com/client/v4/zones/${cf_zone_id}/dns_records?type=${record_type}&name=${record_name}" \
        -H "Authorization: Bearer ${cf_key}" \
        -H "Content-Type: application/json" 2>&1)"; then
    fail_reason="查询 DNS 记录失败"
    err "$fail_reason"
    printf '%s\n' "$json" >&2
    exit 1
  fi
  cf_record_id="$(json_get_first "$json" "id")"
  existing_ip="$(json_get_first "$json" "content")"
  if [ -n "$cf_record_id" ]; then
    ok "已存在记录: ${record_name} → ${existing_ip:-<空>}"
  else
    warn "未找到现有记录，将新建: ${record_name}"
  fi
}

update_record() {
  local json
  action="跳过更新"
  if [ "${existing_ip:-}" = "$current_ip" ]; then
    result_message="DNS 记录 IP 未变化，无需更新"
    warn "$result_message"
    return 0
  fi
  action="更新记录"
  step "更新 DNS 记录 ${existing_ip:-<空>} → ${current_ip} ..."
  if ! json="$(curl -fsS --max-time 20 -X PUT \
        "https://api.cloudflare.com/client/v4/zones/${cf_zone_id}/dns_records/${cf_record_id}" \
        -H "Authorization: Bearer ${cf_key}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${current_ip}\",\"proxied\":${cf_proxy}}" 2>&1)"; then
    fail_reason="更新 DNS 记录失败（请求未成功）"
    err "$fail_reason"
    printf '%s\n' "$json" >&2
    exit 1
  fi
  if json_success "$json"; then
    result_message="DNS 记录更新成功"
    ok "$result_message"
  else
    fail_reason="DNS 记录更新失败"
    err "$fail_reason"
    printf '%s\n' "$json" >&2
    exit 1
  fi
}

create_record() {
  local json
  action="创建记录"
  step "创建新 DNS 记录 ${record_name} → ${current_ip} ..."
  if ! json="$(curl -fsS --max-time 20 -X POST \
        "https://api.cloudflare.com/client/v4/zones/${cf_zone_id}/dns_records" \
        -H "Authorization: Bearer ${cf_key}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${current_ip}\",\"proxied\":${cf_proxy}}" 2>&1)"; then
    fail_reason="创建 DNS 记录失败（请求未成功）"
    err "$fail_reason"
    printf '%s\n' "$json" >&2
    exit 1
  fi
  if json_success "$json"; then
    result_message="DNS 记录创建成功"
    ok "$result_message"
  else
    fail_reason="DNS 记录创建失败"
    err "$fail_reason"
    printf '%s\n' "$json" >&2
    exit 1
  fi
}

print_final_result() {
  local end_time
  end_time="$(date +"%Y-%m-%d %H:%M:%S")"
  if compact; then
    printf '成功|%s|%s|%s|%s -> %s\n' \
      "$action" "$record_type" "$record_name" "${existing_ip:-<none>}" "${current_ip:-<unknown>}"
    return 0
  fi
  section "执行结果"
  kv "操作"       "$action"
  kv "记录类型"   "$record_type"
  kv "主域名"     "$domain"
  kv "记录名称"   "$record_name"
  kv "当前 IP"    "${current_ip:-<未知>}"
  kv "原记录 IP"  "${existing_ip:-<无>}"
  kv "代理状态"   "$cf_proxy"
  kv "Zone ID"    "${cf_zone_id:-<未知>}"
  kv "开始时间"   "$start_time"
  kv "结束时间"   "$end_time"
  [ -n "${result_message:-}" ] && kv "结果说明" "$result_message"
  line
  printf '%s%s%s\n\n' "$c_green" "  ✓ DDNS 执行完毕" "$c_reset"
}

get_public_ip
get_zone_id
get_dns_record

if [ -n "${cf_record_id:-}" ]; then
  update_record
else
  create_record
fi

print_final_result
exit 0
