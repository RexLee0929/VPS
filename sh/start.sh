#!/usr/bin/env bash
# ==============================================================================
#  start.sh — VPS 一键初始化编排（DDNS / 代理 / 配置 / 哪吒探针 / SSH）
#  版本 : v2.2
#  规范 : sh/UNIFIED v2（与 ddns.sh / ssh.sh / env.sh / proxy.sh / nezha.sh 共用同一套写法）
#
#  v2.1 拆分：
#    · 代理安装/配置 → proxy.sh（soga 默认 2.13.4，--soga-version 可换；config 参数空白即报错）
#    · 哪吒探针安装 → nezha.sh
#    · start.sh 只做编排：加载 env、补参、按 --choice 用长选项透传给上述脚本
#  v2.2 整合：
#    · SSH 配置 → 委托 ssh.sh（--choice=7 改全部并重启 / --choice=8 仅加公钥）
#    · 「全部执行」会在【提供了任何 SSH 设置】时自动带上 SSH 步骤，否则跳过（避免意外重启 sshd）
#
#  v2 主要改动：
#    1. 长选项成为唯一权威接口，短选项仅兼容保留（四脚本串联不再传错）
#    2. env 文件【不存在 / 内容缺失】时不再直接退出：
#         · 交互式：逐项提示你手工输入
#         · 非交互：一次性列出所有缺失项 + 可复制的补全命令
#       并可用 --cf-key / --domain1 / --webapi-url ... 等长选项显式补齐
#    3. 取值优先级：命令行 > VPS_* 环境变量 > env 文件 > 交互输入 > 报错
#    4. 加 --save-env 把最终配置落回 env 文件，供 ssh.sh / ddns.sh 复用
#
#  示例:
#    ./start.sh --prefix=home --ss-id=3 --vmess-id=4 --choice=6
#    ./start.sh --cf-key=cfut_xxx --domain1=example.com --choice=2
#    ./start.sh --env=/root/vps.env --choice=1 --dry-run
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
SCRIPT_VERSION="2.2.0"

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
#  start.sh 自身部分
# ==============================================================================

USAGE_LINE="[--env <文件|URL>] [--choice <0-8>] [env 缺失时的手动补参] [SSH 参数] [选项]"
USAGE_NOTE="执行项 --choice:
  1 全部执行   2 仅 DDNS   3 装代理   4 改配置   5 装哪吒   6 装代理+改配置
  7 SSH 改全部并重启        8 SSH 仅添加公钥        0 退出
  （3/4/6 委托 proxy.sh，5 委托 nezha.sh，7/8 委托 ssh.sh，参数长选项同名透传）
  ⚠️ --choice=1 只在【提供了任何 SSH 设置】时才带上 SSH 步骤，否则跳过（不会平白重启 sshd）

env 缺失 / 内容不全时，可用这些长选项手动补齐（优先级最高）:
  --cf-key      Cloudflare API Token      --cf-email    Cloudflare 邮箱
  --domain1     主域名 1                  --domain2     主域名 2
  --webapi-url  v2board webapi 地址       --webapi-key  v2board webapi key
  --nezha-ip    哪吒面板 IP/域名          --nezha-port  哪吒面板端口
  --nezha-tls   true|false                --nezha-key   哪吒 Agent Secret
  --soga-version soga 版本（默认 2.13.4）

SSH（委托 ssh.sh；不传就沿用 ssh.sh 自己的默认值 22/yes/yes/no/3/yes）:
  --ssh-port            端口              --ssh-root-login      PermitRootLogin yes|no
  --ssh-password-auth   yes|no            --ssh-empty-passwords yes|no
  --ssh-max-auth-tries  次数              --ssh-pubkey-auth     yes|no
  --ssh-pubkey          公钥整行          --ssh-pubkey-file     公钥文件
  --ssh-pubkey-name     env 里的 pubkey_<名称>
  --ssh-config          sshd_config 路径  --ssh-action          1|2（--choice=1 时用）
  --ssh-skip-restart                      --ssh-env             传给 ssh.sh 的 env 文件

对应的环境变量（一次导出，各脚本都能用）:
  VPS_CF_KEY  VPS_CF_EMAIL  VPS_DOMAIN1  VPS_DOMAIN2
  VPS_WEBAPI_URL  VPS_WEBAPI_KEY  VPS_SOGA_VERSION
  VPS_NEZHA_IP  VPS_NEZHA_PORT  VPS_NEZHA_TLS  VPS_NEZHA_KEY
  VPS_SSH_PORT  VPS_SSH_ROOT_LOGIN  VPS_SSH_PASSWORD_AUTH  VPS_SSH_EMPTY_PASSWORDS
  VPS_SSH_MAX_AUTH_TRIES  VPS_SSH_PUBKEY_AUTH  VPS_SSH_PUBKEY  VPS_SSH_CONFIG  VPS_SSH_CHOICE
  VPS_PREFIX  VPS_SS_ID  VPS_VMESS_ID  VPS_CHOICE  VPS_NZ_UUID  VPS_ENV

示例:
  $SCRIPT_NAME --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6
  $SCRIPT_NAME --choice=7 --ssh-port=2222 --ssh-root-login=no --ssh-password-auth=no --ssh-pubkey-file=/root/k.pub
  $SCRIPT_NAME --choice=8 --ssh-pubkey-file=/root/mykey.pub
  $SCRIPT_NAME --env=vps.env --choice=1 --dry-run

说明:
  · 取值优先级：命令行 > VPS_* 环境变量 > env 文件 > 交互输入 > 报错
  · 缺项在交互模式会逐项询问；非交互模式一次性列全并退出（--force 可改为跳过）
  · proxy.sh 的 config 对空白参数一律报错；只装不配置用 --choice=3
  · SSH 改动有锁门风险：改端口前先放行新端口；关闭密码登录前先确认公钥能登
  · 退出码：0 全部成功（含 --force 主动跳过）；1 有步骤失败；2 选项/参数错误"

def_opt env        f 1 A_ENV       "env 文件路径或 URL（默认 vps.env）"
def_opt prefix     R 1 A_PREFIX    "DNS 记录前缀（record_prefix）"
def_opt ss-id      S 1 A_SSID      "Shadowsocks 节点 ID"
def_opt vmess-id   V 1 A_VMESSID   "Vmess 节点 ID"
def_opt choice     C 1 A_CHOICE    "执行项 0-8（不给则交互选择）"
def_opt nz-uuid    U 1 A_NZUUID    "哪吒探针 UUID"
# --- env 缺失时的手动补参 ---
def_opt cf-key     - 1 A_CFKEY     "Cloudflare API Token（覆盖/补充 env）"
def_opt cf-email   - 1 A_CFEMAIL   "Cloudflare 账号邮箱"
def_opt domain1    - 1 A_DOMAIN1   "主域名 1"
def_opt domain2    - 1 A_DOMAIN2   "主域名 2"
def_opt webapi-url - 1 A_WEBURL    "v2board webapi 地址"
def_opt webapi-key - 1 A_WEBKEY    "v2board webapi key"
def_opt nezha-ip   - 1 A_NZIP      "哪吒面板 IP 或域名"
def_opt nezha-port - 1 A_NZPORT    "哪吒面板端口"
def_opt nezha-tls  - 1 A_NZTLS     "哪吒面板是否 TLS true|false"
def_opt nezha-key  - 1 A_NZKEY     "哪吒 Agent Secret"
# --- 其他 ---
def_opt save-env   - 1 A_SAVEENV   "把最终配置写回指定 env 文件"
def_opt ddns-script - 1 A_DDNSSH   "指定 ddns.sh 路径（默认自动查找/下载）"
def_opt force      - 0 A_FORCE     "参数缺失时跳过对应步骤而不是退出"
# --- v2.1 拆分后的委托选项 ---
def_opt soga-version - 1 A_SOGAVER "soga 版本（默认 2.13.4，透传给 proxy.sh）"
def_opt proxy-script - 1 A_PROXYSH "指定 proxy.sh 路径（默认自动查找/下载）"
def_opt nezha-script - 1 A_NEZHASH "指定 nezha.sh 路径（默认自动查找/下载）"
# --- v2.2 SSH（委托 ssh.sh；留空即用 ssh.sh 自己的默认值） ---
def_opt ssh-port           - 1 A_SSHPORT    "SSH 端口（默认 22）"
def_opt ssh-root-login     - 1 A_SSHROOT    "PermitRootLogin yes|no"
def_opt ssh-password-auth  - 1 A_SSHPASS    "PasswordAuthentication yes|no"
def_opt ssh-empty-passwords - 1 A_SSHEMPTY  "PermitEmptyPasswords yes|no"
def_opt ssh-max-auth-tries - 1 A_SSHMAX     "MaxAuthTries"
def_opt ssh-pubkey-auth    - 1 A_SSHPUBAUTH "PubkeyAuthentication yes|no"
def_opt ssh-pubkey         - 1 A_SSHPUBKEY  "公钥整行内容"
def_opt ssh-pubkey-file    - 1 A_SSHPUBFILE "从文件读取公钥"
def_opt ssh-pubkey-name    - 1 A_SSHPUBNAME "从 env 文件读取 pubkey_<名称>"
def_opt ssh-config         - 1 A_SSHCONFIG  "sshd_config 路径（默认 /etc/ssh/sshd_config）"
def_opt ssh-action         - 1 A_SSHACTION  "SSH 操作 1|2（仅 --choice=1 时生效）"
def_opt ssh-skip-restart   - 0 A_SSHSKIP    "SSH 改完不重启（透传 --skip-restart）"
def_opt ssh-env            - 1 A_SSHENV     "传给 ssh.sh 的 env 文件（默认沿用本脚本的 env）"
def_opt ssh-script         - 1 A_SSHSCRIPT  "指定 ssh.sh 路径（默认自动查找/下载）"
def_common_opts

parse_cli "$@" || exit $?

REPO_RAW="https://raw.githubusercontent.com/RexLee0929/VPS/main"

# ==============================================================================
#  1. 定位并加载 env 文件（缺失不退出，改用手动传参）
# ==============================================================================
ENV_NAME="vps.env"
env_file="$(cfg_get env VPS_ENV - "vps.env")"
env_source="<未加载>"

section "1/5 加载 env 文件"
if is_url "$env_file"; then
  step "从 URL 下载 env: $env_file"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "dry-run：跳过下载，按空 env 继续（可用手动参数补齐）"
  else
    download "$env_file" "$ENV_NAME" || die "env 下载失败: $env_file"
    load_env_file "$ENV_NAME" && env_source="URL:${env_file}"
  fi
elif [ -f "$env_file" ]; then
  load_env_file "$env_file" && env_source="文件:${env_file}"
  ok "已加载 env: ${env_file}（$(grep -cE '^[A-Za-z_][A-Za-z0-9_]*=' "$env_file" 2>/dev/null || echo 0) 个键）"
else
  warn "未找到 env 文件: ${env_file}"
  log "进入【手动传参模式】：可用 --cf-key / --domain1 / --webapi-url 等长选项，"
  log "或导出对应的 VPS_* 环境变量；交互模式下也会逐项询问。"
fi

# ==============================================================================
#  2. 解析全部配置（命令行 > 环境变量 > env 文件 > 默认）
# ==============================================================================
cf_key="$(cfg_get cf-key     VPS_CF_KEY        cf_key             "")"
cf_email="$(cfg_get cf-email VPS_CF_EMAIL      cf_email           "")"
domain1="$(cfg_get domain1   VPS_DOMAIN1       domain1            "")"
domain2="$(cfg_get domain2   VPS_DOMAIN2       domain2            "")"
webapi_url="$(cfg_get webapi-url VPS_WEBAPI_URL v2board_webapi_url "")"
webapi_key="$(cfg_get webapi-key VPS_WEBAPI_KEY v2board_webapi_key "")"
nezha_ip="$(cfg_get nezha-ip   VPS_NEZHA_IP     nezha_panel_ip     "")"
nezha_port="$(cfg_get nezha-port VPS_NEZHA_PORT nezha_panel_port   "")"
nezha_tls="$(cfg_get nezha-tls  VPS_NEZHA_TLS   nezha_panel_tls    "false")"
nezha_key="$(cfg_get nezha-key  VPS_NEZHA_KEY   nezha_agent_key    "")"

record_prefix="$(cfg_get prefix VPS_PREFIX record_prefix "")"
ss_node_id="$(cfg_get ss-id VPS_SS_ID - "")"
vmess_node_id="$(cfg_get vmess-id VPS_VMESS_ID - "")"
choice="$(cfg_get choice VPS_CHOICE - "")"
nz_uuid="$(cfg_get nz-uuid VPS_NZ_UUID - "")"
save_env_path="$(cfg_get save-env - - "")"
ddns_script_opt="$(cfg_get ddns-script - - "")"
soga_version="$(cfg_get soga-version VPS_SOGA_VERSION - "2.13.4")"
proxy_script_opt="$(cfg_get proxy-script - - "")"
nezha_script_opt="$(cfg_get nezha-script - - "")"

# SSH（env 文件键名与 ssh.sh 完全一致 ⇒ vps.env / ssh.env 都能直接喂给 ssh.sh）
ssh_action="$(cfg_get ssh-action VPS_SSH_CHOICE ssh_choice "")"
ssh_port="$(cfg_get ssh-port VPS_SSH_PORT ssh_port "")"
ssh_root_login="$(cfg_get ssh-root-login VPS_SSH_ROOT_LOGIN ssh_permit_root_login "")"
ssh_password_auth="$(cfg_get ssh-password-auth VPS_SSH_PASSWORD_AUTH ssh_password_auth "")"
ssh_empty_passwords="$(cfg_get ssh-empty-passwords VPS_SSH_EMPTY_PASSWORDS ssh_permit_empty_passwords "")"
ssh_max_auth_tries="$(cfg_get ssh-max-auth-tries VPS_SSH_MAX_AUTH_TRIES ssh_max_auth_tries "")"
ssh_pubkey_auth="$(cfg_get ssh-pubkey-auth VPS_SSH_PUBKEY_AUTH ssh_pubkey_auth "")"
ssh_pubkey="$(cfg_get ssh-pubkey VPS_SSH_PUBKEY - "")"
ssh_pubkey_file="$(cfg_get ssh-pubkey-file - - "")"
ssh_pubkey_name="$(cfg_get ssh-pubkey-name - - "")"
ssh_config="$(cfg_get ssh-config VPS_SSH_CONFIG ssh_config "")"
ssh_env_opt="$(cfg_get ssh-env - - "")"
ssh_script_opt="$(cfg_get ssh-script - - "")"
[ -n "$nezha_tls" ] && nezha_tls="$(normalize_bool "$nezha_tls")"

# 传给 ssh.sh 的 env 文件：显式 --ssh-env 优先，否则沿用本脚本的 env（仅当它可用）
if [ -n "$ssh_env_opt" ]; then
  ssh_env_for_child="$ssh_env_opt"
elif is_url "$env_file"; then
  ssh_env_for_child="$env_file"
elif [ -f "$env_file" ]; then
  ssh_env_for_child="$env_file"
else
  ssh_env_for_child=""
fi

# 是否"用户表达过要动 SSH"：任一 SSH 参数 / VPS_SSH_* 变量 / env 文件里的 ssh_* 键
ssh_params_given() {
  local lo en
  for lo in ssh-action ssh-port ssh-root-login ssh-password-auth ssh-empty-passwords \
            ssh-max-auth-tries ssh-pubkey-auth ssh-pubkey ssh-pubkey-file ssh-pubkey-name ssh-config; do
    [ "${OPT_SET[$lo]:-0}" = "1" ] && return 0
  done
  for en in VPS_SSH_CHOICE VPS_SSH_PORT VPS_SSH_ROOT_LOGIN VPS_SSH_PASSWORD_AUTH \
            VPS_SSH_EMPTY_PASSWORDS VPS_SSH_MAX_AUTH_TRIES VPS_SSH_PUBKEY_AUTH \
            VPS_SSH_PUBKEY VPS_SSH_CONFIG; do
    [ -n "${!en:-}" ] && return 0
  done
  for en in ssh_choice ssh_port ssh_permit_root_login ssh_password_auth \
            ssh_permit_empty_passwords ssh_max_auth_tries ssh_pubkey_auth ssh_config; do
    [ -n "${ENVF[$en]:-}" ] && return 0
  done
  return 1
}

# 长值截断显示（公钥整行太长）
trunc() {
  local s="$1" n="${2:-40}"
  if [ "${#s}" -gt "$n" ]; then printf '%s…' "${s:0:$n}"; else printf '%s' "$s"; fi
}

# ---- 交互补齐：仅当值为空且当前是 TTY ----
fill_var() {
  local vn="$1" tip="$2" lo="$3" sec="${4:-no}"
  local cur ans=""
  cur="${!vn:-}"
  [ -n "$cur" ] && return 0
  [ -t 0 ] || { miss "${lo}" "${tip}"; return 1; }
  [ "$ASSUME_YES" -eq 1 ] && { miss "${lo}" "${tip}"; return 1; }
  ans="$(ask "${tip}（直接回车跳过，或用 ${lo} 传入）" "$sec")" || ans=""
  if [ -n "$ans" ]; then
    printf -v "$vn" '%s' "$ans"
    return 0
  fi
  miss "${lo}" "${tip}"
  return 1
}

if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
  MANUAL_TIP=1
else
  MANUAL_TIP=0
fi

section "2/5 配置解析结果（来源已标注，敏感值已脱敏）"
kv3 "env"          "$env_file"      "$env_source"
kv3 "prefix"       "$record_prefix" "$(cfg_src prefix VPS_PREFIX record_prefix)"
kv3 "cf-key"       "$cf_key"        "$(cfg_src cf-key VPS_CF_KEY cf_key)" yes
kv3 "cf-email"     "$cf_email"      "$(cfg_src cf-email VPS_CF_EMAIL cf_email)"
kv3 "domain1"      "$domain1"       "$(cfg_src domain1 VPS_DOMAIN1 domain1)"
kv3 "domain2"      "$domain2"       "$(cfg_src domain2 VPS_DOMAIN2 domain2)"
kv3 "webapi-url"   "$webapi_url"    "$(cfg_src webapi-url VPS_WEBAPI_URL v2board_webapi_url)"
kv3 "webapi-key"   "$webapi_key"    "$(cfg_src webapi-key VPS_WEBAPI_KEY v2board_webapi_key)" yes
kv3 "nezha-ip"     "$nezha_ip"      "$(cfg_src nezha-ip VPS_NEZHA_IP nezha_panel_ip)"
kv3 "nezha-port"   "$nezha_port"    "$(cfg_src nezha-port VPS_NEZHA_PORT nezha_panel_port)"
kv3 "nezha-tls"    "$nezha_tls"     "$(cfg_src nezha-tls VPS_NEZHA_TLS nezha_panel_tls)"
kv3 "nezha-key"    "$nezha_key"     "$(cfg_src nezha-key VPS_NEZHA_KEY nezha_agent_key)" yes
kv3 "ss-id"        "$ss_node_id"    "$(cfg_src ss-id VPS_SS_ID -)"
kv3 "vmess-id"     "$vmess_node_id" "$(cfg_src vmess-id VPS_VMESS_ID -)"
kv3 "soga-version" "$soga_version"  "$(cfg_src soga-version VPS_SOGA_VERSION -)"
kv3 "nz-uuid"      "$nz_uuid"       "$(cfg_src nz-uuid VPS_NZ_UUID -)"
kv3 "ssh-action"   "$ssh_action"    "$(cfg_src ssh-action VPS_SSH_CHOICE ssh_choice)"
kv3 "ssh-port"     "$ssh_port"      "$(cfg_src ssh-port VPS_SSH_PORT ssh_port)"
kv3 "ssh-root-login" "$ssh_root_login" "$(cfg_src ssh-root-login VPS_SSH_ROOT_LOGIN ssh_permit_root_login)"
kv3 "ssh-password-auth" "$ssh_password_auth" "$(cfg_src ssh-password-auth VPS_SSH_PASSWORD_AUTH ssh_password_auth)"
kv3 "ssh-pubkey-auth" "$ssh_pubkey_auth" "$(cfg_src ssh-pubkey-auth VPS_SSH_PUBKEY_AUTH ssh_pubkey_auth)"
kv3 "ssh-pubkey"   "$(trunc "$ssh_pubkey" 40)" "$(cfg_src ssh-pubkey VPS_SSH_PUBKEY -)"

# ==============================================================================
#  3. 选择执行项
# ==============================================================================
section "3/5 选择执行项"
if [ -z "$choice" ]; then
  if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    warn "未给 --choice，进入交互选择"
    echo "  1. 全部执行          2. 仅 DDNS        3. 安装代理"
    echo "  4. 修改配置文件      5. 安装哪吒探针   6. 安装代理并修改配置"
    echo "  7. SSH 改全部并重启  8. SSH 仅加公钥   0. 退出"
    choice="$(ask "请输入 [0/1/2/3/4/5/6/7/8]" || true)"
  else
    err "未给 --choice，且当前非交互（加 --choice 或 --yes）"
    exit 2
  fi
fi
case "$choice" in
  0|1|2|3|4|5|6|7|8) ;;
  "") err "未选择执行项"; exit 2 ;;
  *)  err "无效的 --choice: $choice（只支持 0-8）"; exit 2 ;;
esac

wants() {
  case "$1" in
    ddns)   case "$choice" in 1|2) return 0 ;; *) return 1 ;; esac ;;
    proxy)  case "$choice" in 1|3|6) return 0 ;; *) return 1 ;; esac ;;
    config) case "$choice" in 1|4|6) return 0 ;; *) return 1 ;; esac ;;
    nezha)  case "$choice" in 1|5) return 0 ;; *) return 1 ;; esac ;;
    ssh)    case "$choice" in 7|8) return 0 ;; *) return 1 ;; esac ;;
  esac
  return 1
}

# ==============================================================================
#  4. 按需补齐缺失参数（交互询问 or 一次性列全）
# ==============================================================================
section "4/5 参数完整性检查"
MISSING=()
if wants ddns; then
  fill_var cf_key "Cloudflare API Token" "--cf-key" yes || true
  fill_var domain1 "主域名（domain1）" "--domain1" || true
fi
if wants config; then
  fill_var webapi_url "v2board webapi 地址" "--webapi-url" || true
  fill_var webapi_key "v2board webapi key" "--webapi-key" yes || true
  fill_var ss_node_id     "Shadowsocks 节点 ID" "--ss-id" || true
  fill_var vmess_node_id  "Vmess 节点 ID"       "--vmess-id" || true
fi
if wants nezha; then
  fill_var nezha_ip   "哪吒面板 IP/域名" "--nezha-ip" || true
  fill_var nezha_port "哪吒面板端口"     "--nezha-port" || true
  fill_var nezha_key  "哪吒 Agent Secret" "--nezha-key" yes || true
fi
if wants ssh; then
  # SSH 没有"必填项"（ssh.sh 各参数都有默认值），但锁门风险要挑明
  case "$(normalize_yesno "$ssh_password_auth")" in
    no) [ -z "${ssh_pubkey}${ssh_pubkey_file}${ssh_pubkey_name}" ] && \
        warn "将关闭密码登录，却没提供任何公钥 —— 请确认已有可用公钥，否则会把自己锁在门外" ;;
  esac
  case "$(normalize_yesno "$ssh_root_login")" in
    no) warn "将设置 PermitRootLogin no —— 请确认你有普通用户可登录并已配好提权" ;;
  esac
  [ -z "$ssh_port" ] && log "未给 --ssh-port，ssh.sh 将按自己的默认值 22 处理"
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  check_missing
  if [ "${OPT_SET[force]:-0}" = "1" ]; then
    warn "已给 --force：相关步骤将被跳过，其余继续执行"
  else
    err "补齐后重试；或用 --force 跳过缺失的步骤；用 --help 查看全部选项"
    exit 2
  fi
else
  ok "本次执行所需的参数齐全"
fi

# ---- --save-env：把最终配置落回文件 ----
if [ -n "$save_env_path" ]; then
  if [ -e "$save_env_path" ] && [ "$ASSUME_YES" -eq 0 ] && ! confirm "覆盖已存在的 ${save_env_path}?"; then
    warn "已取消写入"
  else
    {
      printf '# 由 start.sh v%s 生成于 %s\n' "$SCRIPT_VERSION" "$(date +"%Y-%m-%d %H:%M:%S")"
      printf 'cf_key=%s\n'              "$cf_key"
      printf 'cf_email=%s\n'            "$cf_email"
      printf 'domain1=%s\n'             "$domain1"
      printf 'domain2=%s\n'             "$domain2"
      printf 'v2board_webapi_url=%s\n'  "$webapi_url"
      printf 'v2board_webapi_key=%s\n'  "$webapi_key"
      printf 'nezha_panel_ip=%s\n'      "$nezha_ip"
      printf 'nezha_panel_port=%s\n'    "$nezha_port"
      printf 'nezha_panel_tls=%s\n'     "$nezha_tls"
      printf 'nezha_agent_key=%s\n'     "$nezha_key"
      # SSH（键名与 ssh.sh 完全一致；只有非空的才写，避免把空值覆盖掉 ssh.sh 默认）
      if [ -n "$ssh_port" ]; then printf 'ssh_port=%s\n' "$ssh_port"; fi
      if [ -n "$ssh_root_login" ]; then printf 'ssh_permit_root_login=%s\n' "$ssh_root_login"; fi
      if [ -n "$ssh_password_auth" ]; then printf 'ssh_password_auth=%s\n' "$ssh_password_auth"; fi
      if [ -n "$ssh_empty_passwords" ]; then printf 'ssh_permit_empty_passwords=%s\n' "$ssh_empty_passwords"; fi
      if [ -n "$ssh_max_auth_tries" ]; then printf 'ssh_max_auth_tries=%s\n' "$ssh_max_auth_tries"; fi
      if [ -n "$ssh_pubkey_auth" ]; then printf 'ssh_pubkey_auth=%s\n' "$ssh_pubkey_auth"; fi
      if [ -n "$ssh_config" ]; then printf 'ssh_config=%s\n' "$ssh_config"; fi
      true
    } > "${save_env_path}.tmp" || die "写入临时文件失败: ${save_env_path}.tmp"
    mv -f "${save_env_path}.tmp" "$save_env_path" || die "写入失败: $save_env_path"
    chmod 600 "$save_env_path" 2>/dev/null || true
    ok "配置已写入: ${save_env_path}（权限 600）"
  fi
fi

# ==============================================================================
#  5. 执行
# ==============================================================================
section "5/5 执行"

# ---- 定位 ddns.sh：本地优先，否则下载；并识别 v1/v2 参数风格 ----
DDNS_SH=""
DDNS_IS_V2=0
locate_ddns() {
  local cand
  if [ -n "$ddns_script_opt" ]; then
    [ -f "$ddns_script_opt" ] || die "--ddns-script 文件不存在: $ddns_script_opt"
    DDNS_SH="$ddns_script_opt"
  else
    for cand in "$(dirname "$0")/ddns.sh" "./ddns.sh" "/usr/local/bin/ddns.sh"; do
      [ -f "$cand" ] && { DDNS_SH="$cand"; break; }
    done
  fi
  if [ -z "$DDNS_SH" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      warn "dry-run：不下载 ddns.sh，仅打印将要执行的命令"
      return 0
    fi
    DDNS_SH="$(mktemp)"
    download "${REPO_RAW}/sh/ddns.sh" "$DDNS_SH" || die "下载 ddns.sh 失败"
    chmod +x "$DDNS_SH"
  fi
  grep -q 'UNIFIED v2' "$DDNS_SH" 2>/dev/null && DDNS_IS_V2=1
  return 0
}

run_ddns() {
  # run_ddns <domain> <record> <type> <proxy>
  local d="$1" r="$2" t="$3" p="$4"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] ddns: ${r} (${t}) proxied=${p}"
    return 0
  fi
  [ -n "$DDNS_SH" ] || { err "ddns.sh 不可用，跳过"; return 1; }
  if [ "$DDNS_IS_V2" -eq 1 ]; then
    bash "$DDNS_SH" --key="$cf_key" --domain="$d" --record="$r" --type="$t" --proxy="$p"
  else
    bash "$DDNS_SH" -k "$cf_key" -e "$cf_email" -d "$d" -r "$r" -t "$t" -p "$p"
  fi
}

execute_ddns() {
  step "执行 DDNS..."
  if [ -z "$cf_key" ] || [ -z "$domain1" ]; then
    warn "DDNS 需要 cf_key / domain1，当前缺失，本步跳过（--force 语义）"
    return 0
  fi
  locate_ddns || return 1
  local rec
  if [ -n "$record_prefix" ]; then rec="${record_prefix}.${domain1}"
  else rec="$domain1"; warn "未给 --prefix，记录名按根域名处理: ${rec}"; fi

  run_ddns "$domain1" "$rec"                     "A"    "false"
  run_ddns "$domain1" "${record_prefix:+$record_prefix-}v6.${domain1}" "AAAA" "false"
  if [ -n "$domain2" ]; then
    run_ddns "$domain2" "${record_prefix:+$record_prefix.}${domain2}" "A" "true"
  fi
  ok "DDNS 步骤完成"
}

# ---- 委托子脚本：proxy.sh / nezha.sh（本地优先，否则下载；要求 UNIFIED v2） ----
HELPER_FLAGS=()
[ "$DRY_RUN" -eq 1 ]    && HELPER_FLAGS+=(--dry-run)
[ "$ASSUME_YES" -eq 1 ] && HELPER_FLAGS+=(--yes)
[ "$USE_COLOR" -eq 0 ]  && HELPER_FLAGS+=(--no-color)

locate_helper() {
  # 用法: locate_helper <文件名> <--xxx-script 覆盖路径> ；结果写入全局 HELPER_PATH
  local name="$1" opt_val="$2" cand
  HELPER_PATH=""
  if [ -n "$opt_val" ]; then
    [ -f "$opt_val" ] || die "指定的 $name 不存在: $opt_val"
    HELPER_PATH="$opt_val"
  else
    for cand in "$(dirname "$0")/$name" "./$name" "/usr/local/bin/$name"; do
      [ -f "$cand" ] && { HELPER_PATH="$cand"; break; }
    done
  fi
  if [ -n "$HELPER_PATH" ] && ! grep -q 'UNIFIED v2' "$HELPER_PATH" 2>/dev/null; then
    warn "${HELPER_PATH} 不是 UNIFIED v2 版本，改为下载最新版"
    HELPER_PATH=""
  fi
  if [ -z "$HELPER_PATH" ] && [ "$DRY_RUN" -eq 0 ]; then
    HELPER_PATH="$(mktemp)"
    download "${REPO_RAW}/sh/$name" "$HELPER_PATH" \
      || { err "下载 $name 失败"; rm -f "$HELPER_PATH"; HELPER_PATH=""; return 1; }
    chmod +x "$HELPER_PATH" 2>/dev/null || true
  fi
  return 0
}

run_proxy_install() {
  step "安装代理（委托 proxy.sh --action=install，soga ${soga_version}）..."
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] bash proxy.sh --action=install --soga-version=${soga_version}"
    return 0
  fi
  locate_helper proxy.sh "$proxy_script_opt" || return 1
  [ -n "$HELPER_PATH" ] || { err "proxy.sh 不可用，跳过"; return 1; }
  bash "$HELPER_PATH" --action=install --soga-version="$soga_version" \
    ${HELPER_FLAGS[@]+"${HELPER_FLAGS[@]}"}
}

run_proxy_config() {
  step "修改配置（委托 proxy.sh --action=config）..."
  if [ -z "$ss_node_id" ] || [ -z "$vmess_node_id" ] || [ -z "$webapi_url" ] || [ -z "$webapi_key" ]; then
    warn "配置修改需要 --ss-id / --vmess-id / --webapi-url / --webapi-key，当前缺失，本步跳过"
    warn "（proxy.sh 对空白参数一律报错，不会拿空值写配置）"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] bash proxy.sh --action=config --ss-id=${ss_node_id} --vmess-id=${vmess_node_id} --webapi-url=${webapi_url} --webapi-key=$(mask "$webapi_key")"
    return 0
  fi
  locate_helper proxy.sh "$proxy_script_opt" || return 1
  [ -n "$HELPER_PATH" ] || { err "proxy.sh 不可用，跳过"; return 1; }
  bash "$HELPER_PATH" --action=config \
    --ss-id="$ss_node_id" --vmess-id="$vmess_node_id" \
    --webapi-url="$webapi_url" --webapi-key="$webapi_key" \
    ${HELPER_FLAGS[@]+"${HELPER_FLAGS[@]}"}
}

run_nezha() {
  step "安装哪吒探针（委托 nezha.sh）..."
  if [ -z "$nezha_ip" ] || [ -z "$nezha_port" ] || [ -z "$nezha_key" ]; then
    warn "安装哪吒需要 --nezha-ip / --nezha-port / --nezha-key，当前缺失，本步跳过"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  [dry-run] bash nezha.sh --nezha-ip=${nezha_ip} --nezha-port=${nezha_port} --nezha-key=$(mask "$nezha_key") --nezha-tls=${nezha_tls}${nz_uuid:+ --nz-uuid=$nz_uuid}"
    return 0
  fi
  locate_helper nezha.sh "$nezha_script_opt" || return 1
  [ -n "$HELPER_PATH" ] || { err "nezha.sh 不可用，跳过"; return 1; }
  local -a nz_args=(--nezha-ip="$nezha_ip" --nezha-port="$nezha_port" --nezha-key="$nezha_key" --nezha-tls="$nezha_tls")
  [ -n "$nz_uuid" ] && nz_args+=(--nz-uuid="$nz_uuid")
  bash "$HELPER_PATH" "${nz_args[@]}" ${HELPER_FLAGS[@]+"${HELPER_FLAGS[@]}"}
}

# run_ssh <ssh.sh 的 --choice 1|2> <动作描述>
# 只把【非空】的值透传过去，空值一律不传 ⇒ ssh.sh 用自己的默认值，
# 避免 start.sh 里再抄一份 SSH 默认值（单一真源）。
run_ssh() {
  local ssh_choice="$1" what="$2"
  step "SSH 配置（委托 ssh.sh --choice=${ssh_choice}，${what}）..."
  local -a a=(--choice="$ssh_choice")
  [ -n "$ssh_port" ]            && a+=(--port="$ssh_port")
  [ -n "$ssh_root_login" ]      && a+=(--root-login="$ssh_root_login")
  [ -n "$ssh_password_auth" ]   && a+=(--password-auth="$ssh_password_auth")
  [ -n "$ssh_empty_passwords" ] && a+=(--empty-passwords="$ssh_empty_passwords")
  [ -n "$ssh_max_auth_tries" ]  && a+=(--max-auth-tries="$ssh_max_auth_tries")
  [ -n "$ssh_pubkey_auth" ]     && a+=(--pubkey-auth="$ssh_pubkey_auth")
  [ -n "$ssh_pubkey" ]          && a+=(--pubkey="$ssh_pubkey")
  [ -n "$ssh_pubkey_file" ]     && a+=(--pubkey-file="$ssh_pubkey_file")
  [ -n "$ssh_pubkey_name" ]     && a+=(--pubkey-name="$ssh_pubkey_name")
  [ -n "$ssh_config" ]          && a+=(--config="$ssh_config")
  [ -n "$ssh_env_for_child" ]   && a+=(--env="$ssh_env_for_child")
  [ "${OPT_SET[ssh-skip-restart]:-0}" = "1" ] && a+=(--skip-restart)
  if [ "$DRY_RUN" -eq 1 ]; then
    # 注意别用 ${a[*]}：它按 IFS（这里是 \n\t）拼接，会把参数用制表符连起来，显示很难看
    local disp
    disp="$(printf '%s ' "${a[@]}")"
    log "  [dry-run] bash ssh.sh ${disp% }"
    return 0
  fi
  locate_helper ssh.sh "$ssh_script_opt" || return 1
  [ -n "$HELPER_PATH" ] || { err "ssh.sh 不可用，跳过"; return 1; }
  bash "$HELPER_PATH" "${a[@]}" ${HELPER_FLAGS[@]+"${HELPER_FLAGS[@]}"}
}

if [ "$DRY_RUN" -eq 1 ]; then
  warn "dry-run：以下不会真正执行，只打印步骤"
fi

# ---- 步骤编排：失败不打断后续，但最后如实上报 ----
STEP_FAIL=0
track() {
  # 跑一个步骤：失败只记录，不中断（--choice=1 的"继续跑完"语义）
  "$@" || STEP_FAIL=1
  return 0
}

case "$choice" in
  0) warn "用户选择退出"; exit 0 ;;
  1)
    track execute_ddns
    track run_proxy_install
    track run_proxy_config
    track run_nezha
    # SSH 只在"提供了任何 SSH 设置"时才跟着跑，避免平白重启 sshd
    if ssh_params_given; then
      track run_ssh "${ssh_action:-1}" "全部执行的自带步骤"
    else
      log "跳过 SSH 步骤：未提供任何 SSH 设置（要改 SSH 用 --choice=7 / 8）"
    fi
    ;;
  2) track execute_ddns ;;
  3) track run_proxy_install ;;
  4) track run_proxy_config ;;
  5) track run_nezha ;;
  6) track run_proxy_install ; track run_proxy_config ;;
  7) track run_ssh "${ssh_action:-1}" "改全部并重启" ;;
  8) track run_ssh 2 "仅添加公钥" ;;
esac

line
if [ "$STEP_FAIL" -eq 0 ]; then
  ok "start.sh 执行完毕"
  exit 0
else
  err "start.sh 执行完毕，但有步骤失败（详见上面的 [ERROR]；退出码 1）"
  exit 1
fi
