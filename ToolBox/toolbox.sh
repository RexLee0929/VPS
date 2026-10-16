#!/usr/bin/env bash
# =============================================================================
# toolbox.sh — Rex Lee's ToolBox（重构版 v3.0.0）
#
# 上游版本: 3453 行单文件菜单版（md5 0918725551b186a3204442a13111b805）
# 重构要点:
#   1. bash 守卫 + shebang + 非 bash 自动 re-exec（修 sh 运行时静默失败）
#   2. 菜单引擎数据驱动 + while 循环（修递归菜单导致的栈增长与双重跳转）
#   3. 包管理器抽象 apt/dnf/yum/pacman/apk/zypper/brew（修 24 处重复系统检测）
#   4. unzip/7z/rar 三套重复菜单收敛为一个压缩包驱动
#   5. 全部下载走临时目录 + 失败校验 + 退出清理（修 CWD 污染与空文件）
#   6. 所有变更操作 dry-run 可预览；改动系统文件前自动备份
#   7. 修复上游十余处功能性 bug（详见随附 HTML 报告）
#
# 用法:
#   bash toolbox.sh [选项]
#
# 选项:
#   -h, --help        显示帮助后退出
#   -V, --version     显示版本后退出
#       --no-color    禁用颜色（亦支持 NO_COLOR 环境变量；非 TTY 自动禁用）
#       --color       强制启用颜色（便于管道/日志留色）
#       --verbose     详细模式，打印实际执行的命令
#       --dry-run     演练模式：只打印将执行的操作，不做任何实际变更
#       --yes         所有交互确认自动回答"是"
#       --self-update 从 GitHub 拉取最新版并替换自身后重启
#
# 退出码: 0 正常退出(含主动跳过) / 1 运行错误 / 2 参数错误
#
# 兼容性: 菜单编号与上游完全一致（系统 1-9 / 软件 1-12 / 科学上网 1-4），
#         各工具子菜单编号亦与上游对齐，肌肉记忆不受影响。
# =============================================================================

# shellcheck disable=SC2034  # 各 *_ITEMS/*_ACTIONS 菜单数组由 menu_loop 经 nameref 消费，shellcheck 无法追踪属误报

# ---- 0. bash 守卫 -------------------------------------------------------------
# 上游无 shebang: 用 sh 执行时(dash) declare -A / [[ ]] / BASH_REMATCH 全部失效
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi
if (( BASH_VERSINFO[0] < 4 || ( BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3 ) )); then
    printf '错误: 本脚本需要 bash >= 4.3（当前 %s）\n' "$BASH_VERSION" >&2
    exit 1
fi

# 不用 set -e: 菜单驱动 + read 在 EOF 时返回非零，错误一律显式判断
set -uo pipefail
IFS=$' \t\n'

# ---- 1. 常量 ------------------------------------------------------------------
SCRIPT_NAME="toolbox.sh"
SCRIPT_VERSION="3.0.0"
REPO_RAW="https://raw.githubusercontent.com/RexLee0929/VPS/main/sh"
FS_DF_URL="https://github.com/RexLee0929/VPS/raw/main/config/df"
RAR_VERSION="623"   # 升级 rar 只需改这一行（rarlinux-x64-<ver>.tar.gz）

# ---- 2. 选项解析 ---------------------------------------------------------------
OPT_VERBOSE=0
DRY_RUN=0
OPT_YES=0
OPT_SELF_UPDATE=0

usage() {
    cat <<'EOF'
用法: bash toolbox.sh [选项]

选项:
  -h, --help        显示帮助后退出
  -V, --version     显示版本后退出
      --no-color    禁用颜色（亦支持 NO_COLOR 环境变量；非 TTY 自动禁用）
      --color       强制启用颜色（覆盖非 TTY 自动禁用，便于管道/日志留色）
      --verbose     详细模式，打印实际执行的命令
      --dry-run     演练模式：只打印将执行的操作，不做任何实际变更
      --yes         所有交互确认自动回答"是"
      --self-update 从 GitHub 拉取最新版并替换自身后重启

菜单: 1 系统菜单 / 2 软件菜单 / 3 科学上网菜单 / 0 退出
EOF
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -h|--help)        usage; exit 0 ;;
            -V|--version)     printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
            --no-color)       USE_COLOR=0 ;;
            --color)          USE_COLOR=1 ;;
            --verbose)        OPT_VERBOSE=1 ;;
            --dry-run)        DRY_RUN=1 ;;
            --yes)            OPT_YES=1 ;;
            --self-update)    OPT_SELF_UPDATE=1 ;;
            --)               shift; break ;;
            *)                printf '错误: 未知选项 %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
        esac
        shift
    done
}

# ---- 3. 颜色（与六脚本套件公共区段同一套定义；那六个不动，这里向它们对齐） --------
# 注意: 必须用 $'\033[...]' ANSI-C 引用生成真实 ESC 字节。
# 早期版本把 "\033[34m" 当普通字符串存，printf '%s' 不解释反斜杠，
# 终端里会输出字面量 \033[34m（颜色整体失效），已按六脚本写法修正。
USE_COLOR=1
[ -t 1 ] || USE_COLOR=0
[ -n "${NO_COLOR:-}" ] && USE_COLOR=0

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

# 菜单着色。上游 purple(重复操作提示) 与 black(黑字,深色终端不可见) 不在六脚本
# 色板内，分别并入 c_cyan 与 c_gray，全库只保留这一套 7 色。
red()    { printf '%s%s%s\n' "$c_red"    "$1" "$c_reset"; }
green()  { printf '%s%s%s\n' "$c_green"  "$1" "$c_reset"; }
yellow() { printf '%s%s%s\n' "$c_yellow" "$1" "$c_reset"; }
blue()   { printf '%s%s%s\n' "$c_blue"   "$1" "$c_reset"; }
orange() { printf '%s%s%s\n' "$c_orange" "$1" "$c_reset"; }
cyan()   { printf '%s%s%s\n' "$c_cyan"   "$1" "$c_reset"; }
gray()   { printf '%s%s%s\n' "$c_gray"   "$1" "$c_reset"; }

# 诊断信息一律走 stderr（stdout 可能被 $(...) 捕获）
err()   { printf '%s%s%s\n' "$c_red"    "$1" "$c_reset" >&2; }
warn()  { printf '%s%s%s\n' "$c_yellow" "$1" "$c_reset" >&2; }
note()  { printf '%s%s%s\n' "$c_orange" "$1" "$c_reset" >&2; }
vlog()  { (( OPT_VERBOSE )) && printf '%s\n' "$1" >&2; return 0; }
die()   { err " $1"; exit "${2:-1}"; }

# ---- 4. 通用基础设施 ------------------------------------------------------------
is_root() { (( EUID == 0 )); }

# dry-run 感知的执行器：所有变更命令都必须经过它
run() {
    if (( DRY_RUN )); then
        note " [dry-run] $(printf '%q ' "$@")"
        return 0
    fi
    vlog " + $(printf '%q ' "$@")"
    "$@"
}

# root 不够但有 sudo 时自动垫 sudo；都没有则明确报错（dry-run 只警告）
sudo_run() {
    if is_root; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        err " 需要 root 权限，但当前非 root 且无 sudo"
        return 1
    fi
}

need_root() {
    if is_root; then return 0; fi
    if (( DRY_RUN )); then
        warn " [dry-run] 当前非 root，实际执行时需要 root 或 sudo"
        return 0
    fi
    if command -v sudo >/dev/null 2>&1; then
        warn " 当前非 root，将使用 sudo 执行特权操作"
        return 0
    fi
    die " 此功能需要 root 权限（且系统无 sudo）"
}

# 确认提示：--yes 或 --dry-run 时自动通过；非 TTY 时取默认值
confirm() {
    local prompt="$1" def="${2:-n}" ans=""
    if (( OPT_YES || DRY_RUN )); then return 0; fi
    if [[ ! -t 0 ]]; then
        [[ "$def" == "y" ]] && return 0
        return 1
    fi
    read -r -p " $prompt [y/n，默认$def]: " ans || ans=""
    ans="${ans:-$def}"
    [[ "$ans" == "y" || "$ans" == "Y" ]]
}

# 读取一个字符串到指定变量名（printf -v，不用 eval）
ask() {
    local __var="$1" __prompt="$2" __val=""
    read -r -p " $__prompt: " __val || __val=""
    printf -v "$__var" '%s' "$__val"
}

# 仅在交互式 TTY 下暂停（管道/测试场景自动跳过）
pause() {
    [[ -t 0 ]] || return 0
    read -n 1 -s -r -p " 按任意键返回菜单... " || true
    printf '\n'
}

# 清屏：非 TTY 时改打分隔线，保证日志可读
cls() {
    if [[ -t 1 ]]; then
        clear
    else
        printf -- '----------------------------------------\n'
    fi
}

draw_header() {
    blue " Rex Lee's ToolBox "
    blue " GitHub: https://github.com/RexLee0929 "
    if (( DRY_RUN )); then orange " [演练模式] 不会做任何实际变更 "; fi
    if (( OPT_VERBOSE )); then orange " [详细模式] "; fi
    if ! is_root; then gray " 提示: 部分功能需要 root，将自动使用 sudo "; fi
}

# 备份文件（带时间戳，同一次运行只备份一次；root 属主文件自动走 sudo）
BACKEDUP_FILES=""
backup_file() {
    local f="$1" bak
    [[ -f "$f" ]] || return 0
    case " $BACKEDUP_FILES " in *" $f "*) return 0 ;; esac
    bak="${f}.tb-$(date +%Y%m%d%H%M%S).bak"
    if (( DRY_RUN )); then
        note " [dry-run] 备份 $f -> $bak"
        BACKEDUP_FILES="$BACKEDUP_FILES $f"
        return 0
    fi
    if run sudo_run cp -a "$f" "$bak"; then
        vlog " 已备份 $f -> $bak"
        BACKEDUP_FILES="$BACKEDUP_FILES $f"
    else
        warn " 备份失败: $f"
        return 1
    fi
}

# 写文件（dry-run 只打印）
write_file() {
    local path="$1" content="$2"
    if (( DRY_RUN )); then
        note " [dry-run] 写入文件: $path"
        return 0
    fi
    printf '%s' "$content" > "$path"
}

# 写 root 属主文件（非 root 时走 sudo tee）
write_file_root() {
    local path="$1" content="$2"
    if (( DRY_RUN )); then
        note " [dry-run] 写入文件: $path"
        return 0
    fi
    if is_root; then
        printf '%s' "$content" > "$path"
    else
        printf '%s' "$content" | sudo_run tee "$path" >/dev/null
    fi
}

install_file() {   # install_file <src> <dst>  （安装可执行文件，root 目录自动 sudo）
    local src="$1" dst="$2"
    if (( DRY_RUN )); then
        note " [dry-run] 安装 $src -> $dst (0755)"
        return 0
    fi
    if is_root; then
        if command -v install >/dev/null 2>&1; then
            install -m 0755 "$src" "$dst"
        else
            cp "$src" "$dst" && chmod 0755 "$dst"
        fi
    else
        if command -v install >/dev/null 2>&1; then
            sudo_run install -m 0755 "$src" "$dst"
        else
            sudo_run cp "$src" "$dst" && sudo_run chmod 0755 "$dst"
        fi
    fi
}

# ---- 5. 下载设施 ---------------------------------------------------------------
TB_TMPDIR=""
init_tmp() {
    if [[ -z "$TB_TMPDIR" ]]; then
        TB_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/toolbox.XXXXXX") || die " 无法创建临时目录"
    fi
}

cleanup() {
    if [[ -n "$TB_TMPDIR" && -d "$TB_TMPDIR" ]]; then
        rm -rf "$TB_TMPDIR" || true
    fi
    return 0
}
trap cleanup EXIT

# fetch <URL> <本地文件名>：成功时把本地路径放到全局 FETCHED
FETCHED=""
fetch() {
    local url="$1" name="$2" dest
    FETCHED=""
    if (( DRY_RUN )); then
        note " [dry-run] 下载 $url"
        return 0
    fi
    init_tmp
    dest="$TB_TMPDIR/$name"
    note " 下载: $url"
    if ! curl -fsSL --connect-timeout 10 --retry 2 -o "$dest" "$url"; then
        err " 下载失败: $url"
        return 1
    fi
    if [[ ! -s "$dest" ]]; then
        err " 下载内容为空: $url"
        return 1
    fi
    FETCHED="$dest"
}

# run_remote <URL> <文件名> <命令...>：下载后在临时目录执行，{f} 替换为本地路径
# 上游把第三方脚本直接下到 CWD（污染目录、CWD 不可写时静默失败）
run_remote() {
    local url="$1" name="$2"
    shift 2
    if (( DRY_RUN )); then
        note " [dry-run] 下载并执行: $url"
        return 0
    fi
    if ! fetch "$url" "$name"; then
        return 1
    fi
    local -a rargs=()
    local arg
    for arg in "$@"; do
        rargs+=("${arg//\{f\}/$FETCHED}")
    done
    ( cd "$TB_TMPDIR" && "${rargs[@]}" )
}

# ---- 6. CJK 列宽对齐 ------------------------------------------------------------
# bash 的 printf %-Ns 按字节补齐，CJK 必然错位；按 UTF-8 首字节自行算列宽
disp_width() {
    # 必须先把 LC_ALL=C 置上再取 ${#s}: C  locale 下字符串按字节计，
    # 循环里也是按字节切，两者必须一致，否则 CJK 宽度算错
    local LC_ALL=C
    local s="$1"
    local w=0 i=0 n b
    n=${#s}
    while (( i < n )); do
        b=$(printf '%d' "'${s:i:1}")
        if   (( b < 0x80 )); then w=$((w+1)); i=$((i+1))
        elif (( b < 0xE0 )); then w=$((w+2)); i=$((i+2))
        elif (( b < 0xF0 )); then w=$((w+2)); i=$((i+3))
        else                     w=$((w+2)); i=$((i+4))
        fi
    done
    printf '%d' "$w"
}

pad_disp() {   # pad_disp <字符串> <目标列宽>
    local s="$1" width="$2" w
    w=$(disp_width "$s")
    if (( w >= width )); then
        printf '%s' "$s"
    else
        printf '%s%*s' "$s" "$(( width - w ))" ""
    fi
}

mask_key() {   # 密钥脱敏展示（完整值仍在服务文件里）
    local k="$1"
    if (( ${#k} <= 8 )); then
        printf '%s' "$k"
    else
        printf '%s****%s' "${k:0:4}" "${k: -4}"
    fi
}

# ---- 7. 系统识别与包管理器抽象 ---------------------------------------------------
OS_ID=""; OS_VERSION_ID=""; OS_PRETTY=""
detect_os() {
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VERSION_ID="${VERSION_ID:-}"
        OS_PRETTY="${PRETTY_NAME:-$OS_ID}"
    else
        OS_ID=$(uname -s)
        OS_VERSION_ID=$(uname -r)
        OS_PRETTY="$OS_ID $OS_VERSION_ID"
    fi
}

PKG_MGR=""
pkg_detect() {
    [[ -n "$PKG_MGR" ]] && return 0
    local c
    for c in apt-get dnf yum pacman apk zypper brew; do
        if command -v "$c" >/dev/null 2>&1; then
            PKG_MGR="$c"
            return 0
        fi
    done
    return 1
}

pkg_install() {
    local pkgs=("$@")
    pkg_detect || { err " 未识别到受支持的包管理器"; return 1; }
    if (( DRY_RUN )); then
        note " [dry-run] $PKG_MGR 安装: ${pkgs[*]}"
        return 0
    fi
    note " 使用 $PKG_MGR 安装: ${pkgs[*]}"
    case "$PKG_MGR" in
        apt-get) sudo_run apt-get update && sudo_run apt-get install -y "${pkgs[@]}" ;;
        dnf)     sudo_run dnf install -y "${pkgs[@]}" ;;
        yum)     sudo_run yum install -y "${pkgs[@]}" ;;
        pacman)  sudo_run pacman -Sy --noconfirm --needed "${pkgs[@]}" ;;
        apk)     sudo_run apk add --no-cache "${pkgs[@]}" ;;
        zypper)  sudo_run zypper install -y "${pkgs[@]}" ;;
        brew)    run brew install "${pkgs[@]}" ;;
    esac
}

pkg_remove() {
    local pkgs=("$@")
    pkg_detect || { err " 未识别到受支持的包管理器"; return 1; }
    if (( DRY_RUN )); then
        note " [dry-run] $PKG_MGR 卸载: ${pkgs[*]}"
        return 0
    fi
    note " 使用 $PKG_MGR 卸载: ${pkgs[*]}"
    case "$PKG_MGR" in
        apt-get) sudo_run apt-get remove -y "${pkgs[@]}" ;;
        dnf)     sudo_run dnf remove -y "${pkgs[@]}" ;;
        yum)     sudo_run yum remove -y "${pkgs[@]}" ;;
        pacman)  sudo_run pacman -Rns --noconfirm "${pkgs[@]}" ;;
        apk)     sudo_run apk del "${pkgs[@]}" ;;
        zypper)  sudo_run zypper remove -y "${pkgs[@]}" ;;
        brew)    run brew uninstall "${pkgs[@]}" ;;
    esac
}

# 工具注册表: key|显示名|检测命令|apt 包|rpm 包(dnf/yum)|pacman 包|apk 包
TOOL_TABLE=(
    "wget|wget|wget|wget|wget|wget|wget"
    "curl|curl|curl|curl|curl|curl|curl"
    "git|git|git|git|git|git|git"
    "nano|nano|nano|nano|nano|nano|nano"
    "screen|screen|screen|screen|screen|screen"
    "unzip|unzip|unzip|unzip|unzip|unzip|unzip"
    "ca-certificates|ca-certificates|update-ca-certificates|ca-certificates|ca-certificates|ca-certificates|ca-certificates"
    "p7zip|7zip|7z|p7zip-full|p7zip|p7zip|p7zip"
    "rar|rar/unrar|unrar|rar unrar|rar unrar|rar unrar|unrar"
)

TOOL_PKGS=()
tool_row() {   # 打印指定 key 的注册行
    local key="$1" row k
    for row in "${TOOL_TABLE[@]}"; do
        IFS='|' read -r k _ <<<"$row"
        if [[ "$k" == "$key" ]]; then
            printf '%s' "$row"
            return 0
        fi
    done
    return 1
}

tool_pkgs() {   # 按当前包管理器解析包名到 TOOL_PKGS
    local key="$1" row k _ _ apt rpm pac apk
    row=$(tool_row "$key") || { err " 未知工具: $key"; return 1; }
    IFS='|' read -r k _ _ apt rpm pac apk <<<"$row"
    pkg_detect || { err " 未识别到受支持的包管理器"; return 1; }
    case "$PKG_MGR" in
        apt-get)         read -ra TOOL_PKGS <<<"$apt" ;;
        dnf|yum|zypper)  read -ra TOOL_PKGS <<<"$rpm" ;;
        pacman)          read -ra TOOL_PKGS <<<"$pac" ;;
        apk)             read -ra TOOL_PKGS <<<"$apk" ;;
        brew)            read -ra TOOL_PKGS <<<"$apt" ;;
    esac
}

tool_installed() {
    local key="$1" row k _ chk _ _ _ _
    row=$(tool_row "$key") || return 1
    IFS='|' read -r k _ chk _ _ _ _ <<<"$row"
    command -v "$chk" >/dev/null 2>&1
}

tool_install() {
    local key="$1"
    need_root
    if tool_installed "$key"; then
        cyan " 您已经安装过 $key 了"
        return 0
    fi
    tool_pkgs "$key" || return 1
    pkg_install "${TOOL_PKGS[@]}" || { err " $key 安装失败"; return 1; }
    ok_msg " $key 安装完成"
}

tool_remove() {
    local key="$1"
    need_root
    if ! tool_installed "$key"; then
        gray " 您没有安装 $key"
        return 0
    fi
    tool_pkgs "$key" || return 1
    pkg_remove "${TOOL_PKGS[@]}" || { err " $key 卸载失败"; return 1; }
    gray " $key 卸载完成"
}

ok_msg() { green " $1"; }

# systemctl 封装（无 systemd 时明确报错，dry-run 只打印）
svc() {
    local action="$1" unit="$2"
    if ! command -v systemctl >/dev/null 2>&1; then
        err " 系统无 systemd，无法管理服务: $unit"
        return 1
    fi
    if (( DRY_RUN )); then
        note " [dry-run] systemctl $action $unit"
        return 0
    fi
    run sudo_run systemctl "$action" "$unit"
}

# ---- 8. 菜单引擎（数据驱动 + 循环，替代上游递归菜单） -----------------------------
# 约定: 动作函数会收到"所选项下标(从0开始)"作为 $1，不需要时可忽略
menu_loop() {   # menu_loop <标题> <项目数组名> <动作数组名>
    local title="$1" iname="$2" aname="$3"
    local -n _ml_items="$iname"
    local -n _ml_actions="$aname"
    local n=${#_ml_items[@]} i choice
    while :; do
        cls
        draw_header
        yellow " ===== ${title} ===== "
        for i in "${!_ml_items[@]}"; do
            green " $((i+1)). ${_ml_items[$i]}"
        done
        printf '\n'
        green " 0. 返回"
        printf '\n'
        read -r -p " 请输入数字: " choice || { printf '\n'; return 0; }
        case "$choice" in
            0)          return 0 ;;
            "")         continue ;;
            *[!0-9]*)   err " 无效的选择，请重新输入"; sleep 1 ;;
            *)
                if (( choice >= 1 && choice <= n )); then
                    "${_ml_actions[$((choice-1))]}" "$((choice-1))"
                    pause
                else
                    err " 无效的选择，请重新输入"
                    sleep 1
                fi
                ;;
        esac
    done
}

# =============================================================================
# 9. 系统设置
# =============================================================================

# ---- 9.1 BBR ----
bbr_run() {
    need_root
    confirm " 即将下载并运行第三方脚本 tcp.sh (chiakge/Linux-NetSpeed)，继续？" || return 0
    run_remote "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" tcp.sh bash tcp.sh \
        || err " tcp.sh 执行失败"
}

# ---- 9.2 时区 ----
TZ_ITEMS=("上海 Asia/Shanghai" "东京 Asia/Tokyo" "纽约 America/New_York"
          "洛杉矶 America/Los_Angeles" "伦敦 Europe/London" "巴黎 Europe/Paris")
TZ_ZONES=("Asia/Shanghai" "Asia/Tokyo" "America/New_York"
          "America/Los_Angeles" "Europe/London" "Europe/Paris")
TZ_ACTIONS=(tz_set tz_set tz_set tz_set tz_set tz_set)

tz_set() {
    local i="${1:-0}"
    local zone="${TZ_ZONES[$i]:-}"
    [[ -n "$zone" ]] || { err " 无效的时区"; return 1; }
    need_root
    if ! command -v timedatectl >/dev/null 2>&1; then
        err " 此系统不支持 timedatectl 命令"
        return 1
    fi
    if (( DRY_RUN )); then
        note " [dry-run] timedatectl set-timezone $zone"
        return 0
    fi
    local current=""
    current=$(timedatectl show --property=Timezone --value 2>/dev/null)
    if [[ "$current" == "$zone" ]]; then
        cyan " 您已经设置过时区为 $zone 了"
        return 0
    fi
    if run sudo_run timedatectl set-timezone "$zone"; then
        ok_msg " 已将时区从 ${current:-未知} 设置为 $zone"
    else
        err " 时区设置失败"
        return 1
    fi
}

tz_menu() { menu_loop "设置时区" TZ_ITEMS TZ_ACTIONS; }

# ---- 9.3 swap ----
SWAP_ITEMS=("设置swap为1G" "设置swap为2G" "设置swap为4G" "自定义swap大小" "删除swap")
SWAP_ACTIONS=(swap_add_1g swap_add_2g swap_add_4g swap_add_custom swap_del)

swap_active() {   # /swapfile 是否已存在（fstab 条目或正在使用）
    if command -v swapon >/dev/null 2>&1; then
        swapon --show 2>/dev/null | awk '{print $1}' | grep -qx '/swapfile' && return 0
    fi
    grep -qE '^[^#]*[[:space:]]/swapfile([[:space:]]|$)' /etc/fstab 2>/dev/null
}

swap_add() {
    local size="$1"
    need_root
    if ! [[ "$size" =~ ^[0-9]+$ ]] || (( size <= 0 )); then
        err " swap 大小必须是正整数（单位 MB）"
        return 1
    fi
    if swap_active; then
        err " 已存在 /swapfile，请先删除当前 swap 再设置"
        return 1
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将创建 ${size}MB /swapfile 并写入 fstab"
        return 0
    fi
    if [[ -d /proc/vz ]]; then
        err " 您的 VPS 基于 OpenVZ，不支持 swap"
        return 1
    fi
    info " 创建 ${size}MB /swapfile ..."
    if command -v fallocate >/dev/null 2>&1 && run sudo_run fallocate -l "${size}M" /swapfile; then
        :
    else
        warn " fallocate 不可用或失败，回退 dd 创建"
        if ! run sudo_run dd if=/dev/zero of=/swapfile bs=1M count="$size" status=none; then
            err " 创建 /swapfile 失败"
            run sudo_run rm -f /swapfile || true
            return 1
        fi
    fi
    run sudo_run chmod 600 /swapfile
    if ! run sudo_run mkswap /swapfile; then
        err " mkswap 失败"
        run sudo_run rm -f /swapfile || true
        return 1
    fi
    if ! run sudo_run swapon /swapfile; then
        err " swapon 失败"
        return 1
    fi
    # 上游 fstab 条目用 defaults，缺 sw 选项 -> 重启后 swap 不生效
    backup_file /etc/fstab
    if ! printf '%s\n' '/swapfile none swap sw 0 0' | run sudo_run tee -a /etc/fstab >/dev/null; then
        err " 写入 /etc/fstab 失败"
        return 1
    fi
    ok_msg " swap 创建成功:"
    cat /proc/swaps 2>/dev/null || true
    grep -E 'SwapTotal|SwapFree' /proc/meminfo 2>/dev/null || true
}

swap_del() {
    need_root
    if ! swap_active; then
        gray " 未发现 /swapfile"
        return 0
    fi
    if ! confirm " 确认删除 /swapfile？"; then
        gray " 已取消"
        return 0
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将关闭并删除 /swapfile，清理 fstab 条目"
        return 0
    fi
    backup_file /etc/fstab
    # 上游 swapoff -a 会连带关闭 zram/其他 swap；这里只关 /swapfile
    run sudo_run swapoff /swapfile || warn " swapoff /swapfile 失败（可能未在启用状态）"
    # 上游 sed '/swapfile/d' 会误删任何含 swapfile 的行；这里只删 /swapfile 条目
    run sudo_run sed -i -E '\#^/swapfile[[:space:]]#d' /etc/fstab
    run sudo_run rm -f /swapfile
    ok_msg " swap 已删除"
}

swap_add_1g()      { swap_add 1024; }
swap_add_2g()      { swap_add 2048; }
swap_add_4g()      { swap_add 4096; }
swap_add_custom() {
    local size=""
    ask size "请输入需要添加的 swap 大小（单位 MB）"
    swap_add "$size"
}
swap_menu() { menu_loop "设置swap" SWAP_ITEMS SWAP_ACTIONS; }

# ---- 9.4 IPv4/IPv6 优先级 ----
GAI_ITEMS=("优先使用 IPv4" "优先使用 IPv6" "删除优先设置还原默认" "验证当前优先级")
GAI_ACTIONS=(gai_v4 gai_v6 gai_reset gai_verify)
GAI_CONF="/etc/gai.conf"

gai_prepare() {   # 确保 gai.conf 存在（部分精简镜像没有）
    if (( DRY_RUN )); then
        note " [dry-run] 确保 $GAI_CONF 存在"
        return 0
    fi
    if [[ ! -f "$GAI_CONF" ]]; then
        printf '%s\n' "# gai.conf (created by toolbox)" | sudo_run tee "$GAI_CONF" >/dev/null || return 1
    fi
}

gai_v4() {
    need_root
    gai_prepare || return 1
    if grep -qE '^precedence[[:space:]]+::ffff:0:0/96[[:space:]]+100' "$GAI_CONF" 2>/dev/null; then
        cyan " 您已经设置过优先使用 IPv4 了"
        return 0
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将设置 IPv4 优先（先清除可能存在的 IPv6 优先）"
        return 0
    fi
    if grep -qE '^label[[:space:]]+2002::/16[[:space:]]+2' "$GAI_CONF"; then
        cyan " 检测到 IPv6 优先设置，本次将一并清除"
    fi
    backup_file "$GAI_CONF"
    run sudo_run sed -i -E '/^label[[:space:]]+2002::\/16[[:space:]]+2/d' "$GAI_CONF"
    printf '%s\n' 'precedence ::ffff:0:0/96  100' | run sudo_run tee -a "$GAI_CONF" >/dev/null
    cyan " 已经成功设置为 IPv4 优先"
}

gai_v6() {
    need_root
    gai_prepare || return 1
    if grep -qE '^label[[:space:]]+2002::/16[[:space:]]+2' "$GAI_CONF" 2>/dev/null; then
        cyan " 您已经设置过优先使用 IPv6 了"
        return 0
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将设置 IPv6 优先（先清除可能存在的 IPv4 优先）"
        return 0
    fi
    if grep -qE '^precedence[[:space:]]+::ffff:0:0/96[[:space:]]+100' "$GAI_CONF"; then
        cyan " 检测到 IPv4 优先设置，本次将一并清除"
    fi
    backup_file "$GAI_CONF"
    run sudo_run sed -i -E '/^precedence[[:space:]]+::ffff:0:0\/96[[:space:]]+100/d' "$GAI_CONF"
    printf '%s\n' 'label 2002::/16   2' | run sudo_run tee -a "$GAI_CONF" >/dev/null
    cyan " 已经成功设置为 IPv6 优先"
}

gai_reset() {
    need_root
    if [[ ! -f "$GAI_CONF" ]]; then
        gray " $GAI_CONF 不存在，无需还原"
        return 0
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将删除 IPv4/IPv6 优先设置"
        return 0
    fi
    backup_file "$GAI_CONF"
    run sudo_run sed -i -E '/^(precedence[[:space:]]+::ffff:0:0\/96|label[[:space:]]+2002::\/16)/d' "$GAI_CONF"
    blue " 已删除 IPv4/IPv6 优先设置，还原为系统默认配置"
}

gai_verify() {
    printf '\n'
    yellow " 验证命令: curl -s ip.p3terx.com"
    printf '\n'
    if command -v curl >/dev/null 2>&1; then
        curl -s --max-time 10 ip.p3terx.com || warn " 请求失败，请检查网络"
    else
        err " 系统无 curl"
    fi
    printf '\n'
    green " 显示 IPv4 地址 -> 当前优先 IPv4；显示 IPv6 地址 -> 当前优先 IPv6"
    printf '\n'
}

gai_menu() { menu_loop "IPv4/IPv6优先级调整" GAI_ITEMS GAI_ACTIONS; }

# ---- 9.5 IPv6 配置（上游搁置项，如实标注） ----
IPV6_ITEMS=("添加 IPv6 配置" "删除 IPv6 配置")
IPV6_ACTIONS=(ipv6_todo ipv6_todo)
ipv6_todo() {
    note " 计划中: 上游此菜单为搁置状态，重构版不提供半成品实现。"
    gray " 如需配置 IPv6，请按发行版使用 netplan / nmcli / /etc/network/interfaces。"
}
ipv6_menu() { menu_loop "配置IPv6" IPV6_ITEMS IPV6_ACTIONS; }

# ---- 9.6 融合怪 ECS ----
ECS_ITEMS=("直接运行融合怪ECS" "screen 运行融合怪ECS" "查看历史评测结果")
ECS_ACTIONS=(ecs_direct ecs_screen ecs_history)

ecs_direct() {
    run_remote "https://github.com/spiritLHLS/ecs/raw/main/ecs.sh" ecs.sh bash ecs.sh \
        || err " ecs.sh 执行失败"
}

ecs_screen() {
    if ! command -v screen >/dev/null 2>&1; then
        err " 未安装 screen，请先到 软件菜单 -> screen 安装"
        return 1
    fi
    if (( DRY_RUN )); then
        note " [dry-run] screen -dmS ecs bash ecs.sh"
        return 0
    fi
    if ! fetch "https://github.com/spiritLHLS/ecs/raw/main/ecs.sh" ecs.sh; then
        return 1
    fi
    screen -dmS ecs bash "$FETCHED"
    ok_msg " 已在 screen 会话 'ecs' 中运行融合怪 ECS"
    blue " 重新进入会话: screen -r ecs"
}

ecs_history() {
    local f found=0
    shopt -s nullglob
    for f in "$HOME"/*ecs* /root/*ecs* ./ecs*; do
        [[ -f "$f" ]] || continue
        ls -l --time-style=long-iso "$f" 2>/dev/null || ls -l "$f"
        found=1
    done
    shopt -u nullglob
    if (( found == 0 )); then
        gray " 未找到历史评测结果（ecs.sh 默认不落盘，建议用 screen 方式运行并自行保存输出）"
    fi
}
ecs_menu() { menu_loop "融合怪ECS" ECS_ITEMS ECS_ACTIONS; }

# ---- 9.7 FinalShell 增强（df 过滤 docker 挂载路径） ----
FS_ITEMS=("过滤 docker 挂载路径" "恢复显示 docker 挂载路径")
FS_ACTIONS=(fs_filter fs_restore)

fs_filter() {
    need_root
    local dst="/usr/local/bin/df"
    if (( DRY_RUN )); then
        note " [dry-run] 将下载 df 过滤器并安装到 $dst"
        return 0
    fi
    if ! fetch "$FS_DF_URL" df-filter; then
        return 1
    fi
    if ! head -n 1 "$FETCHED" | grep -q '^#!'; then
        err " 下载内容不是可执行脚本，已中止（未改动 $dst）"
        return 1
    fi
    # 打标记，便于恢复时识别"这是本工具装的过滤器"而非系统原件
    printf '\n# toolbox-finalshell-df\n' >> "$FETCHED"
    # 已存在且不是本工具装的情况下才备份，避免把自己的过滤器当原件备份
    if [[ -f "$dst" ]] && ! grep -q 'toolbox-finalshell-df' "$dst" 2>/dev/null; then
        backup_file "$dst"
        note " 已备份原 $dst"
    fi
    if ! install_file "$FETCHED" "$dst"; then
        err " 安装到 $dst 失败"
        return 1
    fi
    ok_msg " 已安装 df 过滤器（恢复显示请选 2）"
}

fs_restore() {
    need_root
    local dst="/usr/local/bin/df" bak=""
    if [[ ! -f "$dst" ]]; then
        gray " $dst 不存在，无需恢复"
        return 0
    fi
    if ! grep -q 'toolbox-finalshell-df' "$dst" 2>/dev/null; then
        gray " $dst 不是本工具安装的过滤器，未改动"
        return 0
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将恢复/移除 $dst"
        return 0
    fi
    bak=$(ls -1t "${dst}".tb-*.bak 2>/dev/null | head -n 1 || true)
    if [[ -n "$bak" && -f "$bak" ]]; then
        run sudo_run cp -a "$bak" "$dst"
        ok_msg " 已从备份恢复: $bak -> $dst"
    else
        run sudo_run rm -f "$dst"
        gray " 无备份，已移除过滤器（系统 df 恢复默认）"
    fi
}
fs_menu() { menu_loop "FinalShell 增强" FS_ITEMS FS_ACTIONS; }

# ---- 9.8 流媒体检测 ----
MEDIA_ITEMS=("执行流媒体检测" "执行 IPv4 流媒体检测" "执行 IPv6 流媒体检测")
MEDIA_ACTIONS=(media_all media_v4 media_v6)
MEDIA_URL="https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh"

media_all() { run_remote "$MEDIA_URL" check.sh bash check.sh || err " 流媒体检测执行失败"; }
media_v4()  { run_remote "$MEDIA_URL" check.sh bash check.sh -M 4 || err " IPv4 流媒体检测执行失败"; }
media_v6()  { run_remote "$MEDIA_URL" check.sh bash check.sh -M 6 || err " IPv6 流媒体检测执行失败"; }
media_menu() { menu_loop "流媒体检测" MEDIA_ITEMS MEDIA_ACTIONS; }

# ---- 9.9 游戏延迟检测 ----
game_run() {
    run_remote "https://raw.githubusercontent.com/lmc999/GamePing/main/GamePing.sh" GamePing.sh bash GamePing.sh \
        || err " 游戏延迟检测执行失败"
}

# =============================================================================
# 10. 软件菜单
# =============================================================================

# ---- 10.1 wget / curl / git ----
WCG_ITEMS=("安装 wget, curl, git" "安装 wget" "安装 curl" "安装 git"
           "卸载 wget, curl, git" "卸载 wget" "卸载 curl" "卸载 git")
WCG_ACTIONS=(wcg_action wcg_action wcg_action wcg_action wcg_action wcg_action wcg_action wcg_action)

wcg_action() {
    local i="${1:-0}"
    case "$i" in
        0)  need_root
            tool_installed wget && tool_installed curl && tool_installed git \
                && { cyan " 您已经安装过 wget, curl 和 git 了"; return 0; }
            tool_pkgs wget || return 1
            local all=("${TOOL_PKGS[@]}")
            tool_pkgs curl || return 1; all+=("${TOOL_PKGS[@]}")
            tool_pkgs git  || return 1; all+=("${TOOL_PKGS[@]}")
            pkg_install "${all[@]}" || { err " 安装失败"; return 1; }
            ok_msg " wget, curl 和 git 安装完成" ;;
        1)  tool_install wget ;;
        2)  tool_install curl ;;
        3)  tool_install git ;;
        4)  need_root
            if ! tool_installed wget && ! tool_installed curl && ! tool_installed git; then
                gray " wget, curl, git 均未安装"
                return 0
            fi
            confirm " 确认卸载 wget, curl, git？" || { gray " 已取消"; return 0; }
            tool_pkgs wget || return 1;  local all=("${TOOL_PKGS[@]}")
            tool_pkgs curl || return 1; all+=("${TOOL_PKGS[@]}")
            tool_pkgs git  || return 1; all+=("${TOOL_PKGS[@]}")
            pkg_remove "${all[@]}" || { err " 卸载失败"; return 1; }
            gray " wget, curl 和 git 卸载完成" ;;
        5)  tool_remove wget ;;
        6)  tool_remove curl ;;
        7)  tool_remove git ;;
    esac
}
wcg_menu() { menu_loop "wget, curl 和 git" WCG_ITEMS WCG_ACTIONS; }

# ---- 10.2 nano ----
NANO_ITEMS=("安装 Nano" "使用 Nano 打开文件" "卸载 Nano")
NANO_ACTIONS=(nano_install nano_open nano_uninstall)
nano_install()   { tool_install nano; }
nano_uninstall() { tool_remove nano; }
nano_open() {
    if ! command -v nano >/dev/null 2>&1; then
        err " 尚未安装 nano，请先安装"
        return 1
    fi
    local filepath=""
    ask filepath "请输入要使用 nano 打开的文件路径"
    [[ -n "$filepath" ]] || { err " 未输入路径"; return 1; }
    nano "$filepath"
}
nano_menu() { menu_loop "Nano" NANO_ITEMS NANO_ACTIONS; }

# ---- 10.3 screen ----
SCREEN_ITEMS=("安装 Screen" "创建新会话" "在会话中执行指令" "查看并进入会话"
              "删除指定会话" "删除所有会话" "卸载 Screen")
SCREEN_ACTIONS=(screen_install screen_new screen_run screen_attach screen_del_one screen_del_all screen_uninstall)
screen_install()   { tool_install screen; }
screen_uninstall() { tool_remove screen; }

screen_new() {
    command -v screen >/dev/null 2>&1 || { err " 尚未安装 screen，请先安装"; return 1; }
    local name=""
    ask name "请输入新会话的名称"
    [[ -n "$name" ]] || { err " 未输入名称"; return 1; }
    screen -S "$name"
}

screen_run() {
    command -v screen >/dev/null 2>&1 || { err " 尚未安装 screen，请先安装"; return 1; }
    local cmd="" name=""
    ask cmd  "请输入要在 screen 会话中执行的命令"
    ask name "请输入会话名称"
    [[ -n "$name" ]] || { err " 未输入会话名称"; return 1; }
    screen -dmS "$name" bash -c "${cmd:-true}; exec bash"
    ok_msg " 已在会话 $name 中启动命令（进入: screen -r $name）"
}

# 列出 Detached 会话到全局数组 SCREEN_SESSIONS
SCREEN_SESSIONS=()
screen_collect() {
    SCREEN_SESSIONS=()
    command -v screen >/dev/null 2>&1 || return 1
    local line
    while IFS= read -r line; do
        [[ -n "$line" ]] && SCREEN_SESSIONS+=("$line")
    done < <(screen -ls 2>/dev/null | grep 'Detached' | awk '{print $1}')
    (( ${#SCREEN_SESSIONS[@]} > 0 ))
}

screen_attach() {
    command -v screen >/dev/null 2>&1 || { err " 尚未安装 screen，请先安装"; return 1; }
    if ! screen_collect; then
        gray " 当前没有运行中的 screen 会话"
        return 0
    fi
    local i choice=""
    printf '\n'
    for i in "${!SCREEN_SESSIONS[@]}"; do
        green " $((i+1)). ${SCREEN_SESSIONS[$i]}"
    done
    printf '\n'
    ask choice "请输入编号选择会话（0 取消）"
    [[ "$choice" == "0" || -z "$choice" ]] && return 0
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#SCREEN_SESSIONS[@]} )); then
        err " 无效的选择"
        return 1
    fi
    screen -r "${SCREEN_SESSIONS[$((choice-1))]}"
}

screen_del_one() {
    command -v screen >/dev/null 2>&1 || { err " 尚未安装 screen，请先安装"; return 1; }
    if ! screen_collect; then
        gray " 当前没有运行中的 screen 会话"
        return 0
    fi
    local i choice=""
    printf '\n'
    for i in "${!SCREEN_SESSIONS[@]}"; do
        green " $((i+1)). ${SCREEN_SESSIONS[$i]}"
    done
    printf '\n'
    ask choice "请输入要删除的会话编号（0 取消）"
    [[ "$choice" == "0" || -z "$choice" ]] && return 0
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#SCREEN_SESSIONS[@]} )); then
        err " 无效的选择"
        return 1
    fi
    screen -X -S "${SCREEN_SESSIONS[$((choice-1))]}" quit
    ok_msg " 已删除会话: ${SCREEN_SESSIONS[$((choice-1))]}"
}

screen_del_all() {
    command -v screen >/dev/null 2>&1 || { err " 尚未安装 screen，请先安装"; return 1; }
    if ! screen_collect; then
        gray " 当前没有运行中的 screen 会话"
        return 0
    fi
    confirm " 确认删除所有 screen 会话？" || { gray " 已取消"; return 0; }
    local s
    for s in "${SCREEN_SESSIONS[@]}"; do
        run screen -X -S "$s" quit
    done
    ok_msg " 已删除所有 screen 会话"
}
screen_menu() { menu_loop "Screen" SCREEN_ITEMS SCREEN_ACTIONS; }

# ---- 10.4 ca-certificates ----
CA_ITEMS=("安装 ca-certificates" "卸载 ca-certificates")
CA_ACTIONS=(ca_install ca_uninstall)
ca_install()   { tool_install ca-certificates; }
ca_uninstall() { tool_remove ca-certificates; }
ca_menu() { menu_loop "ca-certificates" CA_ITEMS CA_ACTIONS; }

# ---- 10.5 SpeedTest CLI ----
SPEEDTEST_ITEMS=("安装 Speedtest CLI" "运行 Speedtest CLI" "指定节点运行" "卸载 Speedtest CLI")
SPEEDTEST_ACTIONS=(speedtest_install speedtest_run speedtest_server speedtest_uninstall)

speedtest_install() {
    need_root
    if command -v speedtest >/dev/null 2>&1; then
        cyan " 您已经安装过 Speedtest CLI"
        return 0
    fi
    detect_os
    case "$OS_ID" in
        ubuntu|debian|raspbian)
            if ! command -v curl >/dev/null 2>&1; then
                tool_install curl || return 1
            fi
            run_remote "https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh" \
                pkgcloud.sh sudo_run bash pkgcloud.sh || { err " 添加源失败"; return 1; }
            pkg_install speedtest || { err " 安装失败"; return 1; }
            ;;
        fedora|centos|redhat|rhel|rocky|almalinux|amzn)
            if ! command -v curl >/dev/null 2>&1; then
                tool_install curl || return 1
            fi
            run_remote "https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh" \
                pkgcloud.sh sudo_run bash pkgcloud.sh || { err " 添加源失败"; return 1; }
            pkg_install speedtest || { err " 安装失败"; return 1; }
            ;;
        Darwin)
            if ! command -v brew >/dev/null 2>&1; then
                err " 未检测到 Homebrew"
                return 1
            fi
            run brew tap teamookla/speedtest || return 1
            run brew update || true
            run brew install speedtest --force || return 1
            ;;
        *)
            err " 不支持的操作系统: $OS_PRETTY"
            return 1
            ;;
    esac
    ok_msg " Speedtest CLI 安装完成"
}

speedtest_run() {
    command -v speedtest >/dev/null 2>&1 || { err " 尚未安装 Speedtest CLI"; return 1; }
    run speedtest
}

speedtest_server() {
    command -v speedtest >/dev/null 2>&1 || { err " 尚未安装 Speedtest CLI"; return 1; }
    local sid=""
    ask sid "请输入 Speedtest 服务器 ID"
    [[ "$sid" =~ ^[0-9]+$ ]] || { err " 服务器 ID 必须是数字"; return 1; }
    run speedtest --server-id="$sid"
}

speedtest_uninstall() {
    need_root
    command -v speedtest >/dev/null 2>&1 || { gray " 尚未安装 Speedtest CLI"; return 0; }
    detect_os
    case "$OS_ID" in
        ubuntu|debian|raspbian) pkg_remove speedtest ;;
        fedora|centos|redhat|rhel|rocky|almalinux|amzn) pkg_remove speedtest ;;
        Darwin) run brew uninstall speedtest ;;
        *) err " 不支持的操作系统: $OS_PRETTY"; return 1 ;;
    esac
    gray " Speedtest CLI 卸载完成"
}
speedtest_menu() { menu_loop "Speedtest CLI" SPEEDTEST_ITEMS SPEEDTEST_ACTIONS; }

# ---- 10.6 Caddy ----
CADDYFILE="/etc/caddy/Caddyfile"
CADDY_SITES_IDX=(); CADDY_SITES_START=(); CADDY_SITES_END=()
CADDY_SITES_NAME=(); CADDY_SITES_ADDR=(); CADDY_SITES_PORT=(); CADDY_SITES_TLS=()

CADDY_ITEMS=("安装 Caddy" "查看 Caddy 配置文件" "添加 Caddy 配置" "删除 Caddy 配置"
             "Caddy 重新加载" "查看 Caddy 运行状态" "启动 Caddy" "停止 Caddy" "重启 Caddy"
             "设置 Caddy 开机启动" "关闭 Caddy 开机启动" "卸载 Caddy")
CADDY_ACTIONS=(caddy_install caddy_show caddy_add caddy_del caddy_reload caddy_status
               caddy_start caddy_stop caddy_restart caddy_enable caddy_disable caddy_uninstall)

caddy_install() {
    need_root
    if command -v caddy >/dev/null 2>&1; then
        cyan " 您已经安装过 Caddy"
        return 0
    fi
    detect_os
    case "$OS_ID" in
        ubuntu|debian|raspbian)
            pkg_install debian-keyring debian-archive-keyring apt-transport-https || return 1
            run_remote "https://dl.cloudsmith.io/public/caddy/stable/gpg.key" caddy.gpg \
                sudo_run bash -c 'gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg {f}' \
                || { err " 导入 GPG key 失败"; return 1; }
            if (( ! DRY_RUN )); then
                printf '%s\n' 'deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb any main' \
                    | sudo_run tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
            else
                note " [dry-run] 写入 apt 源 caddy-stable.list"
            fi
            pkg_install caddy || return 1
            ;;
        fedora)
            pkg_install 'dnf-command(copr)' || true
            run sudo_run dnf copr enable @caddy/caddy -y || return 1
            pkg_install caddy || return 1
            ;;
        centos|redhat|rhel|rocky|almalinux)
            if [[ "$OS_VERSION_ID" == 7* ]]; then
                pkg_install yum-plugin-copr || true
                run sudo_run yum copr enable @caddy/caddy -y || return 1
                pkg_install caddy || return 1
            else
                pkg_install 'dnf-command(copr)' || true
                run sudo_run dnf copr enable @caddy/caddy -y || return 1
                pkg_install caddy || return 1
            fi
            ;;
        arch)
            pkg_install caddy || return 1
            ;;
        alpine)
            pkg_install caddy || return 1
            ;;
        *)
            err " 不支持的操作系统: $OS_PRETTY"
            return 1
            ;;
    esac
    ok_msg " Caddy 安装完成"
}

caddy_parse() {   # 解析 Caddyfile 到全局数组；返回 1 表示无配置或无文件
    CADDY_SITES_IDX=(); CADDY_SITES_START=(); CADDY_SITES_END=()
    CADDY_SITES_NAME=(); CADDY_SITES_ADDR=(); CADDY_SITES_PORT=(); CADDY_SITES_TLS=()
    if [[ ! -f "$CADDYFILE" ]]; then
        return 1
    fi
    local idx start end name addr port tls
    while IFS='|' read -r idx start end name addr port tls; do
        [[ -n "$idx" ]] || continue
        CADDY_SITES_IDX+=("$idx")
        CADDY_SITES_START+=("$start")
        CADDY_SITES_END+=("$end")
        CADDY_SITES_NAME+=("$name")
        CADDY_SITES_ADDR+=("$addr")
        CADDY_SITES_PORT+=("$port")
        CADDY_SITES_TLS+=("$tls")
    done < <(awk '
        BEGIN { count = 0; have = 0 }
        /^[^[:space:]#]+[[:space:]]*\{/ {
            if (have) { printf "%d|%d|%d|%s|%s|%s|%s\n", count, start, -1, site, addr, port, tls; have = 0 }
            count++; site = $1; start = NR; addr = "-"; port = "-"; tls = "未启用"; have = 1; next
        }
        have && /^[[:space:]]*reverse_proxy[[:space:]]/ { split($2, a, ":"); addr = a[1]; port = a[2]; next }
        have && /^[[:space:]]*tls([[:space:]]|\{)/ { tls = "已启用"; next }
        have && /^\}/ { printf "%d|%d|%d|%s|%s|%s|%s\n", count, start, NR, site, addr, port, tls; have = 0; next }
        END { if (have) printf "%d|%d|%d|%s|%s|%s|%s\n", count, start, -1, site, addr, port, tls }
    ' "$CADDYFILE")
    (( ${#CADDY_SITES_IDX[@]} > 0 ))
}

caddy_table() {
    local i
    printf '%s\n' "┌──────┬────────────────────────┬──────────────┬──────────┬──────────┐"
    printf '│%s│%s│%s│%s│%s│\n' \
        "$(pad_disp ' 序号 ' 6)" "$(pad_disp ' 站点 ' 24)" \
        "$(pad_disp ' 监听地址 ' 12)" "$(pad_disp ' 端口 ' 8)" "$(pad_disp ' TLS ' 8)"
    printf '%s\n' "├──────┼────────────────────────┼──────────────┼──────────┼──────────┤"
    for i in "${!CADDY_SITES_IDX[@]}"; do
        printf '│%s│%s│%s│%s│%s│\n' \
            "$(pad_disp " ${CADDY_SITES_IDX[$i]} " 6)" \
            "$(pad_disp " ${CADDY_SITES_NAME[$i]} " 24)" \
            "$(pad_disp " ${CADDY_SITES_ADDR[$i]} " 12)" \
            "$(pad_disp " ${CADDY_SITES_PORT[$i]} " 8)" \
            "$(pad_disp " ${CADDY_SITES_TLS[$i]} " 8)"
    done
    printf '%s\n' "└──────┴────────────────────────┴──────────────┴──────────┴──────────┘"
}

caddy_show() {
    if ! caddy_parse; then
        if [[ ! -f "$CADDYFILE" ]]; then
            gray " 未找到 $CADDYFILE"
        else
            gray " Caddyfile 中暂无站点配置块"
        fi
        return 0
    fi
    caddy_table
}

caddy_add() {
    need_root
    if [[ ! -f "$CADDYFILE" ]] && (( ! DRY_RUN )); then
        if ! sudo_run mkdir -p "$(dirname "$CADDYFILE")"; then
            return 1
        fi
        printf '%s\n' "# Caddyfile (created by toolbox)" | sudo_run tee "$CADDYFILE" >/dev/null
    fi
    local site="" listen="localhost" port="" tls="" block=""
    ask site   "请输入站点（例如 nmsl.baidu.com）"
    [[ -n "$site" ]] || { err " 站点不能为空"; return 1; }
    ask listen "请输入监听地址（默认 localhost）"
    listen="${listen:-localhost}"
    ask port   "请输入监听端口（例如 7800）"
    [[ "$port" =~ ^[0-9]+$ ]] || { err " 端口必须是数字"; return 1; }
    ask tls    "是否启用 TLS (y/n)"
    if [[ "$tls" == "y" || "$tls" == "Y" ]]; then
        block=$(printf '\n%s {\n    reverse_proxy %s:%s\n    tls {\n        on_demand\n    }\n}\n' "$site" "$listen" "$port")
    else
        block=$(printf '\n%s {\n    reverse_proxy %s:%s\n}\n' "$site" "$listen" "$port")
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将向 $CADDYFILE 追加:\n$block"
        return 0
    fi
    backup_file "$CADDYFILE"
    printf '%s' "$block" | sudo_run tee -a "$CADDYFILE" >/dev/null
    ok_msg " 配置添加完成（执行 5 重新加载生效）"
}

caddy_del() {
    need_root
    if ! caddy_parse; then
        gray " 没有可删除的配置"
        return 0
    fi
    caddy_table
    local choice=""
    ask choice "请输入要删除的配置序号（0 取消）"
    [[ "$choice" == "0" || -z "$choice" ]] && return 0
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#CADDY_SITES_IDX[@]} )); then
        err " 无效的序号"
        return 1
    fi
    local i=$((choice-1))
    local start="${CADDY_SITES_START[$i]}"
    local end="${CADDY_SITES_END[$i]}"
    if ! [[ "$end" =~ ^[0-9]+$ ]] || (( end <= 0 )); then
        err " 该配置块没有闭合，无法安全删除（请手工检查 $CADDYFILE）"
        return 1
    fi
    confirm " 确认删除配置 ${CADDY_SITES_NAME[$i]}？" || { gray " 已取消"; return 0; }
    if (( DRY_RUN )); then
        note " [dry-run] 将删除 $CADDYFILE 第 ${start}-${end} 行"
        return 0
    fi
    backup_file "$CADDYFILE"
    # 上游 awk 'NR < start || NR > end + 1' 有 off-by-one，删除后会残留一行
    if ! sudo_run sed -i "${start},${end}d" "$CADDYFILE"; then
        err " 删除失败"
        return 1
    fi
    if command -v caddy >/dev/null 2>&1; then
        if ! caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1; then
            warn " caddy validate 未通过，请检查 $CADDYFILE"
        fi
    fi
    ok_msg " 配置已删除"
}

caddy_reload()  { svc reload caddy; }
caddy_status()  { svc status caddy; }
caddy_start()   { svc start caddy; }
caddy_stop()    { svc stop caddy; }
caddy_restart() { svc restart caddy; }
caddy_enable()  { svc enable caddy; }
caddy_disable() { svc disable caddy; }

caddy_uninstall() {
    need_root
    command -v caddy >/dev/null 2>&1 || { gray " 尚未安装 Caddy"; return 0; }
    confirm " 确认卸载 Caddy？" || { gray " 已取消"; return 0; }
    pkg_detect || { err " 未识别包管理器"; return 1; }
    case "$PKG_MGR" in
        apt-get) pkg_remove caddy ;;
        dnf|yum) pkg_remove caddy ;;
        pacman)  pkg_remove caddy ;;
        apk)     pkg_remove caddy ;;
        brew)    pkg_remove caddy ;;
        *) err " 请手工卸载 Caddy"; return 1 ;;
    esac
    gray " Caddy 卸载完成"
}
caddy_menu() { menu_loop "Caddy" CADDY_ITEMS CADDY_ACTIONS; }

# ---- 10.7 aapanel ----
AAPANEL_ITEMS=("安装 aapanel")
AAPANEL_ACTIONS=(aapanel_install)
aapanel_install() {
    need_root
    detect_os
    local url=""
    case "$OS_ID" in
        centos|rocky|almalinux|rhel|redhat)
            url="https://www.aapanel.com/script/install_6.0_en.sh" ;;
        ubuntu|debian|deepin)
            url="https://www.aapanel.com/script/install-ubuntu_6.0_en.sh" ;;
        *)
            err " 不支持的操作系统: $OS_PRETTY"
            return 1 ;;
    esac
    # 上游用明文 http 下载安装器（可被中间人注入），已改为 https
    if (( DRY_RUN )); then
        note " [dry-run] 下载并执行 $url"
        return 0
    fi
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        err " 需要 wget 或 curl"
        return 1
    fi
    if command -v wget >/dev/null 2>&1; then
        run_remote "$url" aapanel.sh bash aapanel.sh aapanel || { err " aapanel 安装失败"; return 1; }
    else
        run_remote "$url" aapanel.sh sudo_run bash aapanel.sh aapanel || { err " aapanel 安装失败"; return 1; }
    fi
    ok_msg " aapanel 安装完成（bt 命令查看面板菜单）"
}
aapanel_menu() { menu_loop "aapanel" AAPANEL_ITEMS AAPANEL_ACTIONS; }

# ---- 10.8 Nezha Agent ----
NEZHA_ITEMS=("安装 NeZha 监控" "管理 NeZha 菜单" "查看 Nezha Agent" "创建 Nezha Agent"
             "启动 Nezha Agent" "停止 Nezha Agent" "重启 Nezha Agent"
             "设置开机启动" "关闭开机启动" "删除 Nezha Agent")
NEZHA_ACTIONS=(nezha_install nezha_manage nezha_show nezha_create
               nezha_ctl_start nezha_ctl_stop nezha_ctl_restart
               nezha_ctl_enable nezha_ctl_disable nezha_del)
NEZHA_NAMES=(); NEZHA_SERVICES=(); NEZHA_IPS=(); NEZHA_PORTS=()
NEZHA_KEYS=(); NEZHA_ACTIVE=(); NEZHA_ENABLED=()

nezha_parse() {
    NEZHA_NAMES=(); NEZHA_SERVICES=(); NEZHA_IPS=(); NEZHA_PORTS=()
    NEZHA_KEYS=(); NEZHA_ACTIVE=(); NEZHA_ENABLED=()
    local dir="${NEZHA_DIR:-/etc/systemd/system}"
    local file name svc execline ip port key active enabled
    # 上游把 nezha-agent.service 显式列出又被通配符匹配一次，会重复登记；单个通配符即可全覆盖
    for file in "$dir"/nezha-agent*.service; do
        [[ -f "$file" ]] || continue
        name="NeZha"
        if [[ "$file" =~ nezha-agent_(.*)\.service ]]; then
            name="${BASH_REMATCH[1]}"
        fi
        svc=$(basename "$file" .service)
        execline=$(grep -m1 '^ExecStart=' "$file" 2>/dev/null)
        [[ -n "$execline" ]] || continue
        ip=$(printf '%s' "$execline"   | sed -n 's/.*-s[[:space:]]\{1,\}\([^:]*\):.*/\1/p')
        port=$(printf '%s' "$execline" | sed -n 's/.*:\([^ ]*\)[[:space:]]\{1,\}-p.*/\1/p')
        key=$(printf '%s' "$execline"  | sed -n 's/.*-p[[:space:]]\{1,\}\(.*\)$/\1/p')
        if command -v systemctl >/dev/null 2>&1; then
            active=$(systemctl is-active "$svc" 2>/dev/null || true)
            enabled=$(systemctl is-enabled "$svc" 2>/dev/null || true)
        else
            active="unknown"; enabled="unknown"
        fi
        NEZHA_NAMES+=("$name"); NEZHA_SERVICES+=("$svc")
        NEZHA_IPS+=("${ip:-?}"); NEZHA_PORTS+=("${port:-?}")
        NEZHA_KEYS+=("$key"); NEZHA_ACTIVE+=("${active:-unknown}"); NEZHA_ENABLED+=("${enabled:-unknown}")
    done
    (( ${#NEZHA_SERVICES[@]} > 0 ))
}

nezha_table() {
    local i
    printf '%s\n' "┌──────┬────────────┬────────────────────┬────────┬────────────────────────┬──────────┬────────────┐"
    printf '│%s│%s│%s│%s│%s│%s│%s│\n' \
        "$(pad_disp ' 序号 ' 6)" "$(pad_disp ' 名称 ' 12)" "$(pad_disp ' Panel IP ' 20)" \
        "$(pad_disp ' 端口 ' 6)" "$(pad_disp ' Key ' 22)" "$(pad_disp ' 状态 ' 8)" "$(pad_disp ' 开机启动 ' 10)"
    printf '%s\n' "├──────┼────────────┼────────────────────┼────────┼────────────────────────┼──────────┼────────────┤"
    for i in "${!NEZHA_SERVICES[@]}"; do
        printf '│%s│%s│%s│%s│%s│%s│%s│\n' \
            "$(pad_disp " $((i+1)) " 6)" \
            "$(pad_disp " ${NEZHA_NAMES[$i]} " 12)" \
            "$(pad_disp " ${NEZHA_IPS[$i]} " 20)" \
            "$(pad_disp " ${NEZHA_PORTS[$i]} " 6)" \
            "$(pad_disp " $(mask_key "${NEZHA_KEYS[$i]}") " 22)" \
            "$(pad_disp " ${NEZHA_ACTIVE[$i]} " 8)" \
            "$(pad_disp " ${NEZHA_ENABLED[$i]} " 10)"
    done
    printf '%s\n' "└──────┴────────────┴────────────────────┴────────┴────────────────────────┴──────────┴────────────┘"
}

nezha_show() {
    if ! nezha_parse; then
        gray " 未发现 Nezha Agent 服务（/etc/systemd/system/nezha-agent*.service）"
        return 0
    fi
    nezha_table
}

nezha_install() {
    need_root
    local use_cn=""
    ask use_cn "是否使用中国镜像？(y/n，默认n)"
    if [[ "$use_cn" == "y" || "$use_cn" == "Y" ]]; then
        run_remote "https://cdn.jsdelivr.net/gh/naiba/nezha@master/script/install.sh" nezha.sh \
            sudo_run env CN=true bash nezha.sh || { err " Nezha 安装失败"; return 1; }
    else
        run_remote "https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh" nezha.sh \
            sudo_run bash nezha.sh || { err " Nezha 安装失败"; return 1; }
    fi
    ok_msg " Nezha 安装流程结束"
}

nezha_manage() {
    need_root
    # 上游选项2 直接跑 CWD 下的 ./nezha.sh，只有先手动下载过才能用；改为每次拉取
    run_remote "https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh" nezha.sh \
        sudo_run bash nezha.sh || err " Nezha 管理菜单执行失败"
}

nezha_create() {
    need_root
    if ! command -v systemctl >/dev/null 2>&1; then
        err " 系统无 systemd"
        return 1
    fi
    local name="" ip="" port="" key=""
    ask name "请输入新的配置名称"
    [[ -n "$name" ]] || { err " 名称不能为空"; return 1; }
    ask ip   "请输入 Panel IP"
    [[ -n "$ip" ]] || { err " Panel IP 不能为空"; return 1; }
    ask port "请输入端口"
    [[ "$port" =~ ^[0-9]+$ ]] || { err " 端口必须是数字"; return 1; }
    ask key  "请输入密钥"
    [[ -n "$key" ]] || { err " 密钥不能为空"; return 1; }
    local dir="${NEZHA_DIR:-/etc/systemd/system}"
    local path="$dir/nezha-agent_${name}.service"
    local content
    content=$(printf '[Unit]\nDescription=Nezha Agent %s\nAfter=syslog.target\n\n[Service]\nType=simple\nUser=root\nGroup=root\nWorkingDirectory=/opt/nezha/agent/\nExecStart=/opt/nezha/agent/nezha-agent -s %s:%s -p %s\nRestart=always\n\n[Install]\nWantedBy=multi-user.target\n' \
        "$name" "$ip" "$port" "$key")
    if (( DRY_RUN )); then
        note " [dry-run] 将写入 $path"
        return 0
    fi
    if ! write_file_root "$path" "$content"; then
        return 1
    fi
    run sudo_run chmod 0644 "$path"
    run sudo_run systemctl daemon-reload
    ok_msg " 服务配置已创建: $path（用 systemctl 启动管理）"
}

nezha_pick() {   # 把选中的服务名放到全局 NEZHA_PICKED；返回 1 表示取消/无效
    NEZHA_PICKED=""
    if ! nezha_parse; then
        gray " 未发现 Nezha Agent 服务"
        return 1
    fi
    nezha_table
    local choice=""
    ask choice "请输入 Nezha Agent 序号（0 取消）"
    [[ "$choice" == "0" || -z "$choice" ]] && return 1
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#NEZHA_SERVICES[@]} )); then
        err " 无效的序号"
        return 1
    fi
    NEZHA_PICKED="${NEZHA_SERVICES[$((choice-1))]}"
    return 0
}

nezha_ctl_start()   { nezha_pick && svc start   "$NEZHA_PICKED"; }
nezha_ctl_stop()    { nezha_pick && svc stop    "$NEZHA_PICKED"; }
nezha_ctl_restart() { nezha_pick && svc restart "$NEZHA_PICKED"; }
nezha_ctl_enable()  { nezha_pick && svc enable  "$NEZHA_PICKED"; }
nezha_ctl_disable() { nezha_pick && svc disable "$NEZHA_PICKED"; }

nezha_del() {
    need_root
    if ! nezha_pick; then
        return 0
    fi
    confirm " 确认删除 Nezha Agent ${NEZHA_PICKED}？" || { gray " 已取消"; return 0; }
    local dir="${NEZHA_DIR:-/etc/systemd/system}"
    local path="$dir/${NEZHA_PICKED}.service"
    if (( DRY_RUN )); then
        note " [dry-run] 将停止并删除 $path"
        return 0
    fi
    backup_file "$path"
    run sudo_run systemctl stop "$NEZHA_PICKED" || true
    run sudo_run systemctl disable "$NEZHA_PICKED" || true
    run sudo_run rm -f "$path"
    run sudo_run systemctl daemon-reload
    ok_msg " Nezha Agent ${NEZHA_PICKED} 已删除"
}
nezha_menu() { menu_loop "哪吒监控" NEZHA_ITEMS NEZHA_ACTIONS; }

# ---- 10.9 Aria2 ----
ARIA2_SERVICE="/etc/systemd/system/aria2.service"
ARIA2_ITEMS=("运行 Aria2 安装脚本" "Aria2 菜单" "修复无法开机启动" "查看运行状态"
             "启动 Aria2" "停止 Aria2" "重启 Aria2" "设置开机启动" "关闭开机启动")
ARIA2_ACTIONS=(aria2_install aria2_manage aria2_fix aria2_status
               aria2_start aria2_stop aria2_restart aria2_enable aria2_disable)

aria2_install() {
    need_root
    if (( DRY_RUN )); then
        note " [dry-run] 下载并运行 aria2.sh (git.io/aria2.sh)"
        return 0
    fi
    pkg_install wget curl ca-certificates || true
    run_remote "https://git.io/aria2.sh" aria2.sh bash aria2.sh || err " aria2 安装脚本执行失败"
}

aria2_manage() {
    if (( DRY_RUN )); then
        note " [dry-run] 下载并运行 aria2.sh"
        return 0
    fi
    run_remote "https://git.io/aria2.sh" aria2.sh bash aria2.sh || err " aria2 菜单执行失败"
}

aria2_fix() {
    need_root
    # 上游把 target_config 定义在 if 分支内，else 分支引用未定义变量 -> 写入空文件
    local target_config
    target_config=$(printf '[Unit]\nDescription=Aria2\nAfter=network.target\n[Service]\nUser=root\nLimitNOFILE=51200\nExecStart=/usr/local/bin/aria2c --conf-path=/root/.aria2c/aria2.conf\nRestart=on-failure\n[Install]\nWantedBy=multi-user.target\n')
    if (( DRY_RUN )); then
        note " [dry-run] 将确保 $ARIA2_SERVICE 为目标配置"
        return 0
    fi
    if [[ -f "$ARIA2_SERVICE" ]]; then
        local current=""
        current=$(cat "$ARIA2_SERVICE" 2>/dev/null)
        if [[ "$current" == "$target_config" ]]; then
            green " Aria2 服务配置已经是目标配置，无需更改"
        else
            backup_file "$ARIA2_SERVICE"
            write_file_root "$ARIA2_SERVICE" "$target_config"
            run sudo_run systemctl daemon-reload
            green " Aria2 服务配置已更新"
        fi
    else
        write_file_root "$ARIA2_SERVICE" "$target_config"
        run sudo_run systemctl daemon-reload
        green " Aria2 服务已创建: $ARIA2_SERVICE"
    fi
    if [[ -f /etc/init.d/aria2 ]]; then
        run sudo_run rm -f /etc/init.d/aria2
        green " 为避免冲突，/etc/init.d/aria2 已删除"
    fi
}

aria2_status()  { svc status aria2; }
aria2_start()   { svc start aria2; }
aria2_stop()    { svc stop aria2; }
aria2_restart() { svc restart aria2; }
aria2_enable()  { svc enable aria2; }
aria2_disable() { svc disable aria2; }
aria2_menu() { menu_loop "Aria2" ARIA2_ITEMS ARIA2_ACTIONS; }

# ---- 10.10 压缩包驱动（unzip / 7zip / rar 三合一） ----
ARCHIVE_TOOL=""    # unzip | 7z | rar
ARCHIVE_LABEL=""

arch_menu() {   # arch_menu <tool> <标签>
    ARCHIVE_TOOL="$1"
    ARCHIVE_LABEL="$2"
    local items=("安装 ${ARCHIVE_LABEL}" "解压文件" "压缩文件夹" "批量解压" "批量压缩"
                 "screen 批量解压" "screen 批量压缩" "卸载 ${ARCHIVE_LABEL}")
    local actions=(arch_install arch_extract arch_compress arch_batch_extract arch_batch_compress
                   arch_screen_extract arch_screen_compress arch_uninstall)
    menu_loop "${ARCHIVE_LABEL}菜单" items actions
}

arch_bin() {   # 实际使用的可执行名
    case "$ARCHIVE_TOOL" in
        unzip) printf 'unzip' ;;
        7z)    printf '7z' ;;
        rar)   if command -v unrar >/dev/null 2>&1; then printf 'unrar'; else printf 'rar'; fi ;;
    esac
}

arch_installed() {
    case "$ARCHIVE_TOOL" in
        unzip) command -v unzip >/dev/null 2>&1 ;;
        7z)    command -v 7z >/dev/null 2>&1 ;;
        rar)   command -v unrar >/dev/null 2>&1 || command -v rar >/dev/null 2>&1 ;;
    esac
}

arch_install() {
    case "$ARCHIVE_TOOL" in
        unzip) tool_install unzip ;;
        7z)    tool_install p7zip ;;
        rar)
            need_root
            detect_os
            if tool_installed rar; then
                cyan " 您已经安装过 rar 和 unrar 了"
                return 0
            fi
            case "$OS_ID" in
                ubuntu|debian)
                    pkg_install rar unrar || return 1 ;;
                centos|redhat|rhel|rocky|almalinux|fedora)
                    # RPM 系官方源没有 rar（RPMFusion nonfree 才有），沿用上游 tarball 方案
                    local machine="" tarball=""
                    machine=$(uname -m)
                    case "$machine" in
                        x86_64|amd64)  tarball="rarlinux-x64-${RAR_VERSION}.tar.gz" ;;
                        aarch64|arm64) tarball="rarlinux-arm64-${RAR_VERSION}.tar.gz" ;;
                        *) err " 不支持的架构: $machine（请到 rarlab.com 手工下载）"; return 1 ;;
                    esac
                    run_remote "https://www.rarlab.com/rar/${tarball}" "$tarball" \
                        sudo_run bash -c 'tar zxf {f} -C /usr/local && ln -sf /usr/local/rar/rar /usr/local/bin/rar && ln -sf /usr/local/rar/unrar /usr/local/bin/unrar' \
                        || { err " rar 安装失败"; return 1; } ;;
                arch)
                    pkg_install rar unrar || return 1 ;;
                alpine)
                    pkg_install unrar || return 1 ;;
                *)
                    err " 不支持的操作系统: $OS_PRETTY"
                    return 1 ;;
            esac
            ok_msg " rar/unrar 安装完成" ;;
    esac
}

arch_uninstall() {
    case "$ARCHIVE_TOOL" in
        unzip) tool_remove unzip ;;
        7z)    tool_remove p7zip ;;
        rar)
            need_root
            if ! arch_installed; then
                gray " 您没有安装 rar/unrar"
                return 0
            fi
            confirm " 确认卸载 rar/unrar？" || { gray " 已取消"; return 0; }
            detect_os
            case "$OS_ID" in
                ubuntu|debian) pkg_remove rar unrar ;;
                centos|redhat|rhel|rocky|almalinux|fedora)
                    run sudo_run rm -f /usr/local/bin/rar /usr/local/bin/unrar
                    run sudo_run rm -rf /usr/local/rar ;;
                arch)     pkg_remove rar unrar ;;
                alpine)   pkg_remove unrar ;;
                *) err " 请手工卸载"; return 1 ;;
            esac
            gray " rar/unrar 卸载完成" ;;
    esac
}

# 构造解压命令到全局 ARCH_CMD
arch_extract_cmd() {   # <文件> <目标目录> <密码>
    local file="$1" dest="$2" pw="$3"
    case "$ARCHIVE_TOOL" in
        unzip)
            ARCH_CMD=(unzip -o)
            [[ -n "$pw" ]] && ARCH_CMD+=(-P "$pw")
            ARCH_CMD+=("$file" -d "$dest") ;;
        7z)
            ARCH_CMD=(7z x -y -o"$dest")
            [[ -n "$pw" ]] && ARCH_CMD+=(-p"$pw")
            ARCH_CMD+=("$file") ;;
        rar)
            if command -v unrar >/dev/null 2>&1; then
                ARCH_CMD=(unrar x -o+ -y)
                [[ -n "$pw" ]] && ARCH_CMD+=(-p"$pw")
                ARCH_CMD+=("$file" "$dest/")
            else
                ARCH_CMD=(rar x -o+ -y)
                [[ -n "$pw" ]] && ARCH_CMD+=(-p"$pw")
                ARCH_CMD+=("$file" "$dest/")
            fi ;;
    esac
}

# 构造压缩命令到全局 ARCH_CMD
arch_compress_cmd() {   # <源路径> <输出文件> <密码>
    local src="$1"
    local archive="$2"
    local pw="$3"
    case "$ARCHIVE_TOOL" in
        unzip)
            ARCH_CMD=(zip -r)
            [[ -n "$pw" ]] && ARCH_CMD+=(-P "$pw")
            ARCH_CMD+=("$archive" "$src") ;;
        7z)
            ARCH_CMD=(7z a)
            [[ -n "$pw" ]] && ARCH_CMD+=(-p"$pw")
            ARCH_CMD+=("$archive" "$src") ;;
        rar)
            ARCH_CMD=(rar a)
            [[ -n "$pw" ]] && ARCH_CMD+=(-p"$pw")
            ARCH_CMD+=("$archive" "$src") ;;
    esac
}

arch_ext() {   # 压缩包后缀
    case "$ARCHIVE_TOOL" in
        unzip) printf 'zip' ;;
        7z)    printf '7z' ;;
        rar)   printf 'rar' ;;
    esac
}

arch_need() {
    if ! arch_installed; then
        err " 尚未安装 ${ARCHIVE_LABEL}，请先选 1 安装"
        return 1
    fi
}

arch_extract() {
    arch_need || return 1
    local file="" dest="" pw=""
    ask file "请输入要解压的文件路径"
    [[ -n "$file" ]] || { err " 未输入文件"; return 1; }
    [[ -f "$file" ]] || { err " 文件不存在: $file"; return 1; }
    ask dest "请输入解压目标目录"
    [[ -n "$dest" ]] || { err " 未输入目标目录"; return 1; }
    ask pw   "请输入密码（无密码直接回车）"
    if (( DRY_RUN )); then
        arch_extract_cmd "$file" "$dest" "$pw"
        note " [dry-run] $(printf '%q ' "${ARCH_CMD[@]}")"
        return 0
    fi
    mkdir -p "$dest" || { err " 无法创建目录: $dest"; return 1; }
    arch_extract_cmd "$file" "$dest" "$pw"
    run "${ARCH_CMD[@]}"
}

arch_compress() {
    arch_need || return 1
    local src="" dest="" pw=""
    ask src  "请输入要压缩的文件夹路径"
    [[ -n "$src" ]] || { err " 未输入路径"; return 1; }
    [[ -d "$src" ]] || { err " 目录不存在: $src"; return 1; }
    ask dest "请输入压缩包存放目录"
    [[ -n "$dest" ]] || { err " 未输入目录"; return 1; }
    ask pw   "请输入密码（无密码直接回车）"
    local out=""
    out="$dest/$(basename "$src").$(arch_ext)"
    if (( DRY_RUN )); then
        arch_compress_cmd "$src" "$out" "$pw"
        note " [dry-run] $(printf '%q ' "${ARCH_CMD[@]}")"
        return 0
    fi
    mkdir -p "$dest" || { err " 无法创建目录: $dest"; return 1; }
    arch_compress_cmd "$src" "$out" "$pw"
    run "${ARCH_CMD[@]}"
}

# 询问"是否统一密码"，返回 0=统一(密码在 PW_UNIFIED) / 1=逐个
PW_UNIFIED=""
arch_ask_pw_mode() {
    local same=""
    ask same "所有文件是否使用相同的密码?（直接回车表示'是'，其他表示'否'）"
    if [[ -z "$same" ]]; then
        ask PW_UNIFIED "请输入统一密码（无密码直接回车）"
        return 0
    fi
    return 1
}

arch_batch_extract() {
    arch_need || return 1
    local dir="" dest="" ext="" f n=0
    ask dir  "请输入包含压缩文件的目录"
    [[ -d "$dir" ]] || { err " 目录不存在: $dir"; return 1; }
    ask dest "请输入解压目标目录"
    [[ -n "$dest" ]] || { err " 未输入目标目录"; return 1; }
    ext=$(arch_ext)
    if (( DRY_RUN )); then
        note " [dry-run] 将批量解压 $dir/*.$ext 到 $dest"
        return 0
    fi
    mkdir -p "$dest" || { err " 无法创建目录: $dest"; return 1; }
    if arch_ask_pw_mode; then
        for f in "$dir"/*."$ext"; do
            [[ -f "$f" ]] || continue
            arch_extract_cmd "$f" "$dest" "$PW_UNIFIED"
            run "${ARCH_CMD[@]}" || warn " 解压失败: $f"
            n=$((n+1))
        done
    else
        local pw=""
        for f in "$dir"/*."$ext"; do
            [[ -f "$f" ]] || continue
            ask pw "为 $f 输入密码（无密码直接回车）"
            arch_extract_cmd "$f" "$dest" "$pw"
            run "${ARCH_CMD[@]}" || warn " 解压失败: $f"
            n=$((n+1))
        done
    fi
    (( n > 0 )) || warn " 目录中没有 .$ext 文件"
    (( n > 0 )) && ok_msg " 批量解压完成，共 $n 个文件"
    return 0
}

arch_batch_compress() {
    arch_need || return 1
    local dir="" dest="" d n=0 out
    ask dir  "请输入包含文件夹的目录"
    [[ -d "$dir" ]] || { err " 目录不存在: $dir"; return 1; }
    ask dest "请输入压缩包存放目录"
    [[ -n "$dest" ]] || { err " 未输入目录"; return 1; }
    if (( DRY_RUN )); then
        note " [dry-run] 将批量压缩 $dir 下所有子目录到 $dest"
        return 0
    fi
    mkdir -p "$dest" || { err " 无法创建目录: $dest"; return 1; }
    local -a dirs=()
    for d in "$dir"/*; do
        [[ -d "$d" ]] && dirs+=("$d")
    done
    if (( ${#dirs[@]} == 0 )); then
        warn " 目录下没有子文件夹"
        return 0
    fi
    if arch_ask_pw_mode; then
        for d in "${dirs[@]}"; do
            out="$dest/$(basename "$d").$(arch_ext)"
            arch_compress_cmd "$d" "$out" "$PW_UNIFIED"
            run "${ARCH_CMD[@]}" || warn " 压缩失败: $d"
            n=$((n+1))
        done
    else
        local pw=""
        for d in "${dirs[@]}"; do
            ask pw "为 $d 输入密码（无密码直接回车）"
            out="$dest/$(basename "$d").$(arch_ext)"
            arch_compress_cmd "$d" "$out" "$pw"
            run "${ARCH_CMD[@]}" || warn " 压缩失败: $d"
            n=$((n+1))
        done
    fi
    ok_msg " 批量压缩完成，共 $n 个文件夹"
}

# screen 批量任务：生成临时脚本(600)后 screen 执行
# 上游把命令拼进 bash -c 字符串，存在引号/转义 bug 且密码暴露在 ps 命令行
arch_screen_task() {   # <模式: extract|compress>
    arch_need || return 1
    if ! command -v screen >/dev/null 2>&1; then
        err " 未安装 screen，请先到 软件菜单 -> screen 安装"
        return 1
    fi
    local mode="$1" dir="" dest="" ext="" f d script="" session=""
    ask dir  "请输入目录"
    [[ -d "$dir" ]] || { err " 目录不存在: $dir"; return 1; }
    ask dest "请输入目标目录"
    [[ -n "$dest" ]] || { err " 未输入目标目录"; return 1; }
    ext=$(arch_ext)
    init_tmp
    if [[ "$mode" == "extract" ]]; then
        session="tb_un${ext}"
        script="$TB_TMPDIR/${session}.sh"
        {
            printf '#!/usr/bin/env bash\nset -uo pipefail\n'
            if arch_ask_pw_mode; then
                for f in "$dir"/*."$ext"; do
                    [[ -f "$f" ]] || continue
                    arch_extract_cmd "$f" "$dest" "$PW_UNIFIED"
                    printf '%q ' "${ARCH_CMD[@]}"; printf '\n'
                done
            else
                local pw=""
                for f in "$dir"/*."$ext"; do
                    [[ -f "$f" ]] || continue
                    ask pw "为 $f 输入密码（无密码直接回车）"
                    arch_extract_cmd "$f" "$dest" "$pw"
                    printf '%q ' "${ARCH_CMD[@]}"; printf '\n'
                done
            fi
        } > "$script"
    else
        session="tb_${ext}"
        script="$TB_TMPDIR/${session}.sh"
        local -a dirs=()
        for d in "$dir"/*; do
            [[ -d "$d" ]] && dirs+=("$d")
        done
        if (( ${#dirs[@]} == 0 )); then
            warn " 目录下没有子文件夹"
            return 0
        fi
        {
            printf '#!/usr/bin/env bash\nset -uo pipefail\n'
            if arch_ask_pw_mode; then
                for d in "${dirs[@]}"; do
                    arch_compress_cmd "$d" "$dest/$(basename "$d").${ext}" "$PW_UNIFIED"
                    printf '%q ' "${ARCH_CMD[@]}"; printf '\n'
                done
            else
                local pw=""
                for d in "${dirs[@]}"; do
                    ask pw "为 $d 输入密码（无密码直接回车）"
                    arch_compress_cmd "$d" "$dest/$(basename "$d").${ext}" "$pw"
                    printf '%q ' "${ARCH_CMD[@]}"; printf '\n'
                done
            fi
        } > "$script"
    fi
    if (( DRY_RUN )); then
        note " [dry-run] 将在 screen 会话 $session 中执行:"
        cat "$script" >&2
        return 0
    fi
    chmod 600 "$script"
    screen -dmS "$session" bash "$script"
    ok_msg " 已在 screen 会话 $session 中启动任务（进入: screen -r $session）"
    gray " 任务脚本: $script（退出工具箱时自动清理）"
}

arch_screen_extract()  { arch_screen_task extract; }
arch_screen_compress() { arch_screen_task compress; }

unzip_menu() { arch_menu unzip unzip; }
p7zip_menu() { arch_menu 7z 7zip; }
rar_menu()   { arch_menu rar rar; }

# =============================================================================
# 11. 科学上网
# =============================================================================
VPN_ITEMS=("安装soga" "安装XrayR" "安装ss-go" "安装极光面板")
VPN_ACTIONS=(soga_menu xrayr_menu ssgo_menu aurora_menu)

SOGA_ITEMS=("安装 soga" "运行 soga")
SOGA_ACTIONS=(soga_install soga_run)
soga_install() {
    run_remote "https://github.com/sprov065/soga/raw/master/soga.sh" soga.sh bash soga.sh install \
        || err " soga 安装失败"
    ok_msg " soga 安装流程结束"
}
soga_run() {
    if ! command -v soga >/dev/null 2>&1; then
        err " 尚未安装 soga，请先安装"
        return 1
    fi
    run soga
}
soga_menu() { menu_loop "soga" SOGA_ITEMS SOGA_ACTIONS; }

XRAYR_ITEMS=("安装 XrayR" "运行 XrayR")
XRAYR_ACTIONS=(xrayr_install xrayr_run)
xrayr_install() {
    run_remote "https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh" xrayr.sh bash xrayr.sh \
        || err " XrayR 安装失败"
    ok_msg " XrayR 安装流程结束"
}
xrayr_run() {
    if ! command -v xrayr >/dev/null 2>&1; then
        err " 尚未安装 XrayR，请先安装"
        return 1
    fi
    run xrayr
}
xrayr_menu() { menu_loop "XrayR" XRAYR_ITEMS XRAYR_ACTIONS; }

SSGO_ITEMS=("安装 ss-go")
SSGO_ACTIONS=(ssgo_install)
ssgo_install() {
    run_remote "https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ss-go.sh" ss-go.sh bash ss-go.sh \
        || err " ss-go 安装失败"
    ok_msg " ss-go 安装流程结束"
}
ssgo_menu() { menu_loop "ss-go" SSGO_ITEMS SSGO_ACTIONS; }

AURORA_ITEMS=("打开极光面板")
AURORA_ACTIONS=(aurora_install)
aurora_install() {
    run_remote "https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh" aurora.sh bash aurora.sh \
        || err " 极光面板安装失败"
}
aurora_menu() { menu_loop "极光面板" AURORA_ITEMS AURORA_ACTIONS; }

# =============================================================================
# 12. 菜单定义（编号与上游完全一致）
# =============================================================================
SYSTEM_ITEMS=("BBR加速" "设置时区" "设置swap" "IPv4/IPv6优先级调整" "配置IPv6"
              "融合怪ECS" "FinalShell 增强" "流媒体检测" "游戏延迟检测")
SYSTEM_ACTIONS=(bbr_run tz_menu swap_menu gai_menu ipv6_menu ecs_menu fs_menu media_menu game_run)

APP_ITEMS=("wget, curl 和 git" "nano" "screen" "unzip" "ca-certificates" "SpeedTest CLI"
           "Caddy" "aapanel" "Nezha Agent" "Aria2" "7zip" "rar")
APP_ACTIONS=(wcg_menu nano_menu screen_menu unzip_menu ca_menu speedtest_menu
             caddy_menu aapanel_menu nezha_menu aria2_menu p7zip_menu rar_menu)

system_menu() { menu_loop "ToolBox 系统菜单" SYSTEM_ITEMS SYSTEM_ACTIONS; }
app_menu()    { menu_loop "ToolBox 软件菜单" APP_ITEMS APP_ACTIONS; }
vpn_menu()    { menu_loop "ToolBox 科学上网菜单" VPN_ITEMS VPN_ACTIONS; }

start_menu() {
    while :; do
        cls
        draw_header
        yellow " ==========ToolBox主菜单============= "
        orange " 1. 系统菜单 "
        orange " 2. 软件菜单 "
        orange " 3. 科学上网菜单 "
        printf '\n'
        orange " 为保证有权限执行,请使用root用户运行 "
        yellow " =================================== "
        green " 0. 退出脚本"
        printf '\n'
        local choice=""
        read -r -p " 请输入数字: " choice || { printf '\n'; return 0; }
        case "$choice" in
            1) system_menu ;;
            2) app_menu ;;
            3) vpn_menu ;;
            0) return 0 ;;
            "") continue ;;
            *) err " 请输入正确数字"; sleep 1 ;;
        esac
    done
}

# ---- 13. 自更新 ----
self_update() {
    if (( DRY_RUN )); then
        note " [dry-run] 将从 $REPO_RAW/toolbox.sh 获取最新版并替换 $0"
        return 0
    fi
    local cur="$0"
    note " 正在获取最新版: $REPO_RAW/toolbox.sh"
    if ! fetch "$REPO_RAW/toolbox.sh" toolbox.new; then
        err " 下载失败，已中止更新"
        return 1
    fi
    if ! bash -n "$FETCHED"; then
        err " 新版本语法检查失败，已中止更新（未改动 $cur）"
        return 1
    fi
    backup_file "$cur"
    if ! install_file "$FETCHED" "$cur"; then
        err " 替换 $cur 失败"
        return 1
    fi
    ok_msg " 已更新到最新版，重新启动..."
    exec bash "$cur"
}

# ---- 14. 入口 ----
main() {
    parse_args "$@"
    init_colors
    detect_os
    if (( OPT_SELF_UPDATE )); then
        self_update
        exit $?
    fi
    vlog " 系统: $OS_PRETTY"
    start_menu
    exit 0
}

main "$@"
