#!/usr/bin/env bash
# ==============================================================================
#  env.sh — 从 1Password 拉取 env 文件
#  版本 : v2.0
#  规范 : sh/UNIFIED v2（与 ddns.sh / ssh.sh / start.sh 共用同一套写法）
#
#  这次重构要解决的事：
#    · 短选项跨脚本撞车（-t 在 env 是 token、在 ddns 是记录类型；
#      -r 在 env 是 op://引用、在 ddns 是记录名）→ 长选项成为唯一权威接口
#    · 参数漏传 → 缺失项一次性列全
#    · 输出默认对齐 start.sh 的默认读取值 vps.env，拉完可直接跑 start.sh
#
#  示例:
#    ./env.sh --token=ops_xxxx --vault=Infra --item=vps-env
#    ./env.sh --token-file=/root/.config/op/token --ref="op://Infra/vps-env/notesPlain"
#    ./env.sh --vault=Infra --item=vps-env --dry-run
# ==============================================================================

# ------------------------------------------------------------------------------
#  公共区段 v2.0 —— ddns.sh / ssh.sh / env.sh / start.sh 四份脚本完全一致
#  ---------------------------------------------------------------------------
#  传参约定（四脚本统一）：
#    1. 长选项是唯一权威接口：--key value 或 --key=value
#       短选项仅为兼容保留，跨脚本含义可能不同 → 串联执行一律用长选项
#    2. 取值优先级：命令行 > VPS_* 环境变量 > env 文件 > 内置默认
#    3. 缺失参数一次性列全，并给出可复制的补全方式
#    4. 通用开关：--dry-run --yes --no-color --verbose --help --version
#    5. 敏感值打印一律脱敏（显示前 4 后 4 与长度）
#  修改本区段时请同步另外三个脚本。
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
    value="${value#\"}"; value="${value%\"}"
    value="${value#\'}"; value="${value%\'}"
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
#  env.sh 自身部分
# ==============================================================================

USAGE_LINE="--token <token> (--ref <op://引用> | --vault <库> --item <条目>) [选项]"
USAGE_NOTE="环境变量（优先级低于命令行）:
  VPS_OP_TOKEN  1Password Service Account token
  VPS_OP_VAULT  保管库名      VPS_OP_ITEM  条目名
  VPS_OP_FIELD  字段名（默认 notesPlain）   VPS_OP_OUT  输出文件（默认 vps.env）

示例:
  $SCRIPT_NAME --token=ops_xxxx --vault=Infra --item=vps-env
  $SCRIPT_NAME --token-file=/root/.config/op/token --ref=op://Infra/vps-env/notesPlain
  $SCRIPT_NAME --vault=Infra --item=vps-env --dry-run

说明:
  · 输出默认就是 vps.env，与 start.sh 的默认读取值一致，拉完可直接跑 start.sh
  · 安全笔记的正文在 CLI 里字段名是 notesPlain；自定义字段用你自己的 label
  · 全程不打印 token，也不打印任何值，只列 KEY 名
  · 跨脚本串联务必用长选项：env 的 -t 是 --token，ddns.sh 的 -t 是 --type"

def_opt token       t 1 A_TOKEN  "1Password Service Account token（必填）"
def_opt token-file  T 1 A_TFILE  "从文件读取 token（首行，自动去掉换行）"
def_opt ref         r 1 A_REF    "完整引用 op://<库>/<条目>/<字段>"
def_opt vault       v 1 A_VAULT  "保管库名"
def_opt item        i 1 A_ITEM   "条目名"
def_opt field       F 1 A_FIELD  "字段名（默认 notesPlain）"
def_opt out         o 1 A_OUT    "输出文件（默认 vps.env）"
def_opt list-keys   - 0 A_KEYS   "只列出已有 env 文件的 KEY 名，不拉取"
def_common_opts

parse_cli "$@" || exit $?

# ---------- 解析取值 ----------
sa_token="$(cfg_get token VPS_OP_TOKEN - "")"
token_file="$(cfg_get token-file - - "")"
op_ref="$(cfg_get ref VPS_OP_REF - "")"
vault="$(cfg_get vault VPS_OP_VAULT - "")"
item="$(cfg_get item VPS_OP_ITEM - "")"
field="$(cfg_get field VPS_OP_FIELD - "notesPlain")"
out_file="$(cfg_get out VPS_OP_OUT - "vps.env")"

# ---------- --list-keys：只读自检 ----------
if [ "${OPT_SET[list-keys]:-0}" = "1" ]; then
  if [ ! -f "$out_file" ]; then err "文件不存在: $out_file"; exit 1; fi
  section "已有 env 文件的 KEY 名（不打印值）"
  grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$out_file" 2>/dev/null | tr -d ' =' | while read -r _k; do
    [ -n "$_k" ] && kv "$_k" "<已设置>"
  done
  exit 0
fi

# ---------- 检查 op ----------
if ! have_cmd op; then
  err "未检测到 1Password CLI（op），请先安装："
  printf '%s\n' "  ARCH=amd64; OP_VERSION=\"v\$(curl -s https://app-updates.agilebits.com/check/1/0/CLI2/en/2.0.0/N | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+')\"" >&2
  printf '%s\n' "  curl -sSfo /tmp/op.zip \"https://cache.agilebits.com/dist/1P/op2/pkg/\${OP_VERSION}/op_linux_\${ARCH}_\${OP_VERSION}.zip\"" >&2
  printf '%s\n' "  unzip -od /usr/local/bin/ /tmp/op.zip && rm /tmp/op.zip" >&2
  exit 1
fi

op_version="$(op --version 2>/dev/null || true)"
if [ -n "$op_version" ]; then
  op_major="$(printf '%s' "$op_version" | awk -F. '{print $1}')"
  op_minor="$(printf '%s' "$op_version" | awk -F. '{print $2}')"
  if [ -z "$op_major" ] || [ -z "$op_minor" ]; then
    warn "无法解析 op 版本号: $op_version"
  elif [ "$op_major" -lt 2 ] 2>/dev/null; then
    die "op 版本过低（$op_version），Service Account 需要 >= 2.18.0"
  elif [ "$op_minor" -lt 18 ] 2>/dev/null; then
    warn "op 版本 $op_version 低于 2.18.0，Service Account 可能不可用，建议升级"
  fi
fi
[ -n "$op_version" ] && log "1Password CLI 版本: $op_version"

# ---------- token：-t > --token-file > 环境变量 ----------
token_src=""
if [ -z "$sa_token" ] && [ -n "$token_file" ]; then
  [ -f "$token_file" ] || die "--token-file 文件不存在: $token_file"
  sa_token="$(tr -d '\r\n' < "$token_file")" || die "读取 token 文件失败: $token_file"
  token_src="文件"
fi
if [ -z "$sa_token" ]; then
  [ -z "$token_src" ] && token_src="环境变量"
else
  [ -z "$token_src" ] && token_src="命令行"
fi
[ -n "$sa_token" ] || miss "--token / --token-file / VPS_OP_TOKEN" "1Password Service Account token"

case "$sa_token" in
  ops_*) ;;
  "")    ;;
  *)     warn "token 不是 ops_ 开头，确认这是 Service Account token 而不是个人账号凭据" ;;
esac

# ---------- 拼引用 ----------
if [ -z "$op_ref" ]; then
  [ -n "$vault" ] || miss "--vault / VPS_OP_VAULT" "保管库名（或直接给 --ref）"
  [ -n "$item" ]  || miss "--item / VPS_OP_ITEM" "条目名（或直接给 --ref）"
  if ! check_missing; then
    err "补齐后重试；或用 --help 查看全部选项"
    exit 2
  fi
  op_ref="op://${vault}/${item}/${field}"
fi

# ---------- 摘要 ----------
section "拉取参数（来源已标注）"
kv3 "token" "$sa_token" "$token_src" yes
kv3 "ref"   "$op_ref"   "$(cfg_src ref VPS_OP_REF -)"
kv3 "out"   "$out_file" "$(cfg_src out VPS_OP_OUT -)"

if [ "$DRY_RUN" -eq 1 ]; then
  warn "dry-run：不会调用 op，也不会写入任何文件"
  log "将要执行:"
  log "  OP_SERVICE_ACCOUNT_TOKEN=<脱敏> op read '${op_ref}' > ${out_file}"
  log "  chmod 600 ${out_file}"
  exit 0
fi

# ---------- 拉取 ----------
tmp_file="$(mktemp)" || die "无法创建临时文件"
chmod 600 "$tmp_file" 2>/dev/null || true

step "正在从 1Password 拉取..."
if ! OP_SERVICE_ACCOUNT_TOKEN="$sa_token" op read "$op_ref" > "$tmp_file" 2>/dev/null; then
  rm -f "$tmp_file"
  die "op read 失败，常见原因：
  · 引用写错（保管库 / 条目 / 字段名大小写敏感）
  · Service Account 未被授权该保管库（新建的保管库不会自动授权）
  · token 已过期或被撤销"
fi

if [ ! -s "$tmp_file" ]; then
  rm -f "$tmp_file"
  die "拉取到的内容是空的（引用可能指向了一个空字段）"
fi

# ---------- 落盘 ----------
if [ -e "$out_file" ]; then
  ts="$(date +%s)"
  cp -a "$out_file" "${out_file}.bak.${ts}" || { rm -f "$tmp_file"; die "备份原文件失败: $out_file"; }
  warn "已备份原文件 -> ${out_file}.bak.${ts}"
  if [ "$ASSUME_YES" -eq 0 ] && ! confirm "确认覆盖 ${out_file}?"; then
    rm -f "$tmp_file"
    warn "已取消，原文件未改动"
    exit 0
  fi
fi

out_dir="$(dirname "$out_file")"
[ -d "$out_dir" ] || mkdir -p "$out_dir" || { rm -f "$tmp_file"; die "创建目录失败: $out_dir"; }

mv -f "$tmp_file" "$out_file" || { rm -f "$tmp_file"; die "写入失败: $out_file"; }
chmod 600 "$out_file" 2>/dev/null || warn "chmod 600 失败（Windows/非 POSIX 文件系统常见）: $out_file"

ok "env 文件已保存: ${out_file}（$(wc -c < "$out_file" | tr -d ' ') 字节）"

# ---------- 结果校验（只列 KEY，不显示值） ----------
section "结果校验（只列 KEY 名）"
keys="$(grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$out_file" 2>/dev/null | tr -d ' =' | tr '\n' ' ' || true)"
if [ -n "$keys" ]; then
  log "解析到的键: ${keys}"
else
  warn "没解析到 KEY=VALUE 行，请检查拉回来的内容格式"
fi

missing=""
for k in cf_key cf_email domain1 domain2 v2board_webapi_url v2board_webapi_key nezha_panel_ip nezha_panel_port nezha_panel_tls nezha_agent_key; do
  grep -qE "^[[:space:]]*${k}=" "$out_file" 2>/dev/null || missing="${missing} ${k}"
done
if [ -n "$missing" ]; then
  warn "以下键未找到（按你的实际配置判断是否需要，也可用 start.sh 的 --cf-key 等手动补）：${missing}"
else
  ok "start.sh 需要的核心键都在"
fi

line
printf '%s%s%s\n' "$c_green" "  拉取完成，可直接执行：" "$c_reset"
printf '  ./start.sh --env=%s --prefix=<前缀> --ss-id=<ID> --vmess-id=<ID> --choice=6\n\n' "$out_file"
exit 0
