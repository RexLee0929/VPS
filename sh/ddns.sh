#!/usr/bin/env bash
#
# ddns.sh - Cloudflare DDNS Script
#

set -o errexit
set -o nounset
set -o pipefail

# 默认配置
DEFAULT_TYPE="A"
DEFAULT_PROXY="false"
DEFAULT_MODE="color"

# 运行参数
cf_key=""
cf_email=""
domain=""
record_name=""
record_type="$DEFAULT_TYPE"
cf_proxy="$DEFAULT_PROXY"
output_mode="$DEFAULT_MODE"

# 运行状态
current_ip=""
existing_ip=""
cf_zone_id=""
cf_record_id=""
api_response=""
action="未执行"
result_status="成功"
result_message=""
start_time="$(date +"%Y-%m-%d %H:%M:%S")"
end_time=""
fail_reason=""
dns_api_json=""
zone_api_json=""

# 控制冒号位置
KEY_WIDTH=12

init_colors() {
    if [ "$output_mode" = "plain" ] || [ "$output_mode" = "compact" ]; then
        c_yellow=""
        c_blue=""
        c_green=""
        c_red=""
        c_orange=""
        c_cyan=""
        c_gray=""
        c_reset=""
    else
        c_yellow="\033[33m"
        c_blue="\033[34m"
        c_green="\033[32m"
        c_red="\033[31m"
        c_orange="\033[38;5;208m"
        c_cyan="\033[36m"
        c_gray="\033[90m"
        c_reset="\033[0m"
    fi
}

log() {
    [ "$output_mode" = "compact" ] && return 0
    printf "%b[INFO]%b %s\n" "${c_blue}" "${c_reset}" "$*"
}

ok() {
    [ "$output_mode" = "compact" ] && return 0
    printf "%b[OK]%b   %s\n" "${c_green}" "${c_reset}" "$*"
}

warn() {
    [ "$output_mode" = "compact" ] && return 0
    printf "%b[WARN]%b %s\n" "${c_orange}" "${c_reset}" "$*"
}

err() {
    printf "%b[ERROR]%b %s\n" "${c_red}" "${c_reset}" "$*"
}

line() {
    printf "%b%s%b\n" "${c_gray}" "────────────────────────────────────────────────────────────" "${c_reset}"
}

section() {
    [ "$output_mode" = "compact" ] && return 0
    echo
    printf "%b%s%b\n" "${c_blue}" "$1" "${c_reset}"
    line
}

usage() {
    cat <<EOF
Usage: $0 -k <cf_key> -e <cf_email> -d <domain> -r <record> [options]

必选参数:
  -k <key>         Cloudflare Global API Key
  -e <email>       Cloudflare 登录邮箱
  -d <domain>      主域名，如 example.com
  -r <record>      完整记录名，如 test.example.com

可选参数:
  -t <type>        记录类型: A | AAAA (默认: A)
  -p <bool>        是否启用 Cloudflare 代理: true | false (默认: false)

输出控制:
  --mode <mode>    输出模式:
                   color   彩色模式（默认）
                   plain   无色普通模式
                   compact 简洁模式（仅输出核心结果）
  --color          强制启用彩色模式
  --no-color       关闭彩色输出（等价于 --mode plain）

帮助:
  -h, --help       显示帮助
EOF
}

# 计算显示宽度：
# ASCII 算 1，非 ASCII 算 2
str_width() {
    local s="$1"
    local width=0
    local i char hex

    while [ -n "$s" ]; do
        char="${s%"${s#?}"}"
        s="${s#?}"

        hex=$(printf '%s' "$char" | LC_ALL=C od -An -tx1 | tr -d ' \n')
        if [ -z "$hex" ]; then
            continue
        fi

        if [ ${#hex} -le 2 ]; then
            width=$((width + 1))
        else
            width=$((width + 2))
        fi
    done

    echo "$width"
}

pad_key() {
    local key="$1"
    local width
    local pad
    width="$(str_width "$key")"
    pad=$((KEY_WIDTH - width))
    [ "$pad" -lt 0 ] && pad=0
    printf "%s%*s" "$key" "$pad" ""
}

kv() {
    local key="$1"
    local value="$2"
    local padded
    padded="$(pad_key "$key")"
    printf "  %b%s%b : %b%s%b\n" \
        "${c_cyan}" "$padded" "${c_reset}" \
        "${c_orange}" "$value" "${c_reset}"
}

normalize_bool() {
    case "${1,,}" in
        1|true|yes|on) echo "true" ;;
        0|false|no|off) echo "false" ;;
        *) echo "$1" ;;
    esac
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

json_get_first() {
    local json="$1"
    local field="$2"

    if has_cmd jq; then
        echo "$json" | jq -r --arg field "$field" '.result[0][$field] // empty' 2>/dev/null || true
    else
        echo "$json" | grep -Po "(?<=\"${field}\":\")[^\"]*" | head -1 || true
    fi
}

json_success() {
    local json="$1"
    if has_cmd jq; then
        [ "$(echo "$json" | jq -r '.success // false' 2>/dev/null)" = "true" ]
    else
        [[ "$json" == *'"success":true'* ]]
    fi
}

set_failure() {
    result_status="失败"
    result_message="$1"
    fail_reason="$1"
}

finish() {
    end_time="$(date +"%Y-%m-%d %H:%M:%S")"
    print_final_result
}

on_error() {
    local exit_code=$?
    if [ "$result_status" != "失败" ]; then
        set_failure "脚本执行过程中发生未捕获错误"
    fi
    finish
    exit "$exit_code"
}

trap on_error ERR

parse_args() {
    local args=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --mode)
                shift
                [ $# -eq 0 ] && { echo "缺少 --mode 的参数"; exit 1; }
                output_mode="$1"
                ;;
            --color)
                output_mode="color"
                ;;
            --no-color)
                output_mode="plain"
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                args+=("$1")
                ;;
        esac
        shift || true
    done

    set -- "${args[@]}"

    while getopts ":k:e:d:r:t:p:h" opt; do
        case "$opt" in
            k) cf_key="$OPTARG" ;;
            e) cf_email="$OPTARG" ;;
            d) domain="$OPTARG" ;;
            r) record_name="$OPTARG" ;;
            t) record_type="$OPTARG" ;;
            p) cf_proxy="$OPTARG" ;;
            h) usage; exit 0 ;;
            \?) echo "无效选项: -$OPTARG"; usage; exit 1 ;;
            :) echo "选项 -$OPTARG 需要参数"; usage; exit 1 ;;
        esac
    done
}

validate_args() {
    case "$output_mode" in
        color|plain|compact) ;;
        *)
            echo "无效的输出模式: $output_mode"
            exit 1
            ;;
    esac

    [ -z "$cf_key" ] && { err "缺少参数: -k cf_key"; usage; exit 1; }
    [ -z "$cf_email" ] && { err "缺少参数: -e cf_email"; usage; exit 1; }
    [ -z "$domain" ] && { err "缺少参数: -d domain"; usage; exit 1; }
    [ -z "$record_name" ] && { err "缺少参数: -r record"; usage; exit 1; }

    case "${record_type^^}" in
        A|AAAA) record_type="${record_type^^}" ;;
        *)
            err "记录类型无效: $record_type，仅支持 A 或 AAAA"
            exit 1
            ;;
    esac

    cf_proxy="$(normalize_bool "$cf_proxy")"
    case "$cf_proxy" in
        true|false) ;;
        *)
            err "代理参数无效: $cf_proxy，仅支持 true 或 false"
            exit 1
            ;;
    esac
}

print_header() {
    [ "$output_mode" = "compact" ] && return 0
    echo
    line
    printf "%b%s%b\n" "${c_blue}" "  Rex Lee's DDNS Script" "${c_reset}"
    printf "%b%s%b\n" "${c_yellow}" "  Cloudflare DDNS Enhanced" "${c_reset}"
    printf "%b%s%b\n" "${c_orange}" "  开始时间：${start_time}" "${c_reset}"
    line
}

print_args_summary() {
    [ "$output_mode" = "compact" ] && return 0
    section "参数摘要"
    kv "Domain" "$domain"
    kv "Record" "$record_name"
    kv "Type" "$record_type"
    kv "Proxy" "$cf_proxy"
    kv "Mode" "$output_mode"
}

get_public_ip() {
    log "正在获取当前公网 IP..."
    if [ "$record_type" = "AAAA" ]; then
        current_ip="$(curl -6 -fsS ip.sb)"
    else
        current_ip="$(curl -4 -fsS ip.sb)"
    fi

    [ -z "$current_ip" ] && {
        set_failure "获取公网 IP 失败"
        err "$fail_reason"
        exit 1
    }

    ok "公网 IP 获取成功: $current_ip"
}

get_zone_id() {
    log "正在获取 Cloudflare Zone ID..."
    zone_api_json="$(curl -fsS -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
        -H "X-Auth-Email: $cf_email" \
        -H "X-Auth-Key: $cf_key" \
        -H "Content-Type: application/json")"

    cf_zone_id="$(json_get_first "$zone_api_json" "id")"

    if [ -z "$cf_zone_id" ]; then
        set_failure "获取 Cloudflare Zone ID 失败"
        err "$fail_reason"
        [ "$output_mode" != "compact" ] && printf "%bAPI Response:%b %s\n" "${c_red}" "${c_reset}" "$zone_api_json"
        exit 1
    fi

    ok "Zone ID 获取成功: $cf_zone_id"
}

get_dns_record() {
    log "正在查询 DNS 记录..."
    dns_api_json="$(curl -fsS -X GET "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records?type=$record_type&name=$record_name" \
        -H "X-Auth-Email: $cf_email" \
        -H "X-Auth-Key: $cf_key" \
        -H "Content-Type: application/json")"

    cf_record_id="$(json_get_first "$dns_api_json" "id")"
    existing_ip="$(json_get_first "$dns_api_json" "content")"

    if [ -n "$cf_record_id" ]; then
        ok "检测到已有 DNS 记录"
    else
        warn "未检测到现有 DNS 记录，将创建新记录"
    fi
}

update_record() {
    log "准备更新现有 DNS 记录..."
    action="跳过更新"

    if [ "${existing_ip:-}" = "$current_ip" ]; then
        result_message="DNS 记录 IP 未变化"
        warn "$result_message"
        return 0
    fi

    action="更新记录"
    api_response="$(curl -fsS -X PUT "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records/$cf_record_id" \
        -H "X-Auth-Email: $cf_email" \
        -H "X-Auth-Key: $cf_key" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$current_ip\",\"proxied\":$cf_proxy}")"

    if json_success "$api_response"; then
        result_message="DNS 记录更新成功"
        ok "$result_message"
    else
        set_failure "DNS 记录更新失败"
        err "$fail_reason"
        [ "$output_mode" != "compact" ] && printf "%bAPI Response:%b %s\n" "${c_red}" "${c_reset}" "$api_response"
        exit 1
    fi
}

create_record() {
    log "准备创建新的 DNS 记录..."
    action="创建记录"

    api_response="$(curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/$cf_zone_id/dns_records" \
        -H "X-Auth-Email: $cf_email" \
        -H "X-Auth-Key: $cf_key" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$current_ip\",\"proxied\":$cf_proxy}")"

    if json_success "$api_response"; then
        result_message="DNS 记录创建成功"
        ok "$result_message"
    else
        set_failure "DNS 记录创建失败"
        err "$fail_reason"
        [ "$output_mode" != "compact" ] && printf "%bAPI Response:%b %s\n" "${c_red}" "${c_reset}" "$api_response"
        exit 1
    fi
}

print_final_result() {
    if [ "$output_mode" = "compact" ]; then
        printf "%s | %s | %s | %s | %s -> %s\n" \
            "$result_status" \
            "$action" \
            "$record_type" \
            "$record_name" \
            "${existing_ip:-<none>}" \
            "${current_ip:-<unknown>}"
        return 0
    fi

    section "执行结果"

    kv "状态" "$result_status"
    kv "操作" "$action"
    line

    kv "记录类型" "$record_type"
    kv "主域名" "$domain"
    kv "记录名称" "$record_name"
    kv "当前 IP" "${current_ip:-<未知>}"
    kv "原记录 IP" "${existing_ip:-<无>}"
    kv "代理状态" "$cf_proxy"
    kv "Zone ID" "${cf_zone_id:-<未知>}"
    kv "开始时间" "$start_time"
    kv "结束时间" "${end_time:-$(date +"%Y-%m-%d %H:%M:%S")}"

    if [ -n "${result_message:-}" ]; then
        kv "结果说明" "$result_message"
    fi

    if [ -n "${fail_reason:-}" ]; then
        kv "失败原因" "$fail_reason"
    fi

    line

    if [ "$result_status" = "成功" ]; then
        printf "%b%s%b\n\n" "${c_green}" "✓ DDNS 脚本执行完毕" "${c_reset}"
    else
        printf "%b%s%b\n\n" "${c_red}" "✗ DDNS 脚本执行失败" "${c_reset}"
    fi
}

main() {
    parse_args "$@"
    init_colors
    validate_args
    print_header
    print_args_summary

    get_public_ip
    get_zone_id
    get_dns_record

    if [ -n "${cf_record_id:-}" ]; then
        update_record
    else
        create_record
    fi

    end_time="$(date +"%Y-%m-%d %H:%M:%S")"
    finish
}

main "$@"
