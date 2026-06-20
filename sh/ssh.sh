#!/bin/bash
#
# ssh.sh - 简易 SSH 配置与公钥管理脚本
# version v1.0 (美化并增强了输入校验、日志与兼容性)
#
# 用法示例：
#   ./ssh.sh -f ssh.env -P 2222 -R no -A no -U yes -K "ssh-rsa AAAA..." -C 1
#

set -o pipefail

# 定义颜色
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

# 必须以 root 运行
if [ "$(id -u)" != "0" ]; then
    red "请以 root 用户运行"
    exit 1
fi

# 默认配置与路径
ssh_config="/etc/ssh/sshd_config"
authorized_keys="/root/.ssh/authorized_keys"

env_file="ssh.env"      # 默认 env 路径或 URL
env_name="ssh.env"      # 下载或本地使用的文件名

# 默认值（可被 env 覆盖或命令行参数覆盖）
default_port=22
default_permit_root_login="yes"
default_password_auth="yes"
default_permit_empty_passwords="no"
default_max_auth_tries=3
default_pubkey_auth="yes"

# 运行时变量（可能来自 env 或参数）
port=""
permit_root_login=""
password_auth=""
permit_empty_passwords=""
max_auth_tries=""
pubkey_auth=""
public_key=""
pubkey_name=""
choice=""

# 简单判断字符串是否为 URL
is_url() {
    [[ $1 =~ ^https?:// ]]
}

# 读取环境变量文件（支持 URL 或本地文件）
load_env() {
    if is_url "$env_file"; then
        yellow "下载 env 文件: $env_file"
        if ! command -v curl >/dev/null 2>&1; then
            red "curl 未安装，无法下载 env 文件"
            exit 1
        fi
        curl -fsSL "$env_file" -o "$env_name" || {
            red "env 下载失败"
            exit 1
        }
    elif [ -f "$env_file" ]; then
        env_name="$env_file"
    else
        # 没有 env 文件，返回但不报错
        return
    fi

    declare -gA env_vars
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"        # 去掉注释
        line="${line%"${line##*[![:space:]]}"}"   # 右 trim
        line="${line#"${line%%[![:space:]]*}"}"   # 左 trim
        [ -z "$line" ] && continue
        if [[ $line =~ ^[a-zA-Z_][a-zA-Z0-9_]*=.+$ ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            # 去除可能的双引号或单引号包裹
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            env_vars[$key]="$value"
        fi
    done < "$env_name"
}

# 将多种 yes/no 表示规范化为 yes 或 no
normalize_yesno() {
    local v="${1,,}"   # 转为小写
    case "$v" in
        1|y|yes|on|true) echo "yes" ;;
        0|n|no|off|false) echo "no" ;;
        *) echo "$v" ;;   # 原样返回（可能为空或已是 yes/no）
    esac
}

# 解析命令行参数
usage() {
    cat <<EOF
Usage: $0 [options]

 -f file_or_url   指定 env 文件或 URL（默认: ssh.env）
 -P port          SSH 端口
 -R yes|no        PermitRootLogin
 -A yes|no        PasswordAuthentication
 -E yes|no        PermitEmptyPasswords
 -M number        MaxAuthTries
 -U yes|no        PubkeyAuthentication
 -K public_key    直接提供公钥字符串（整行）
 -N pubkey_name   从 env 文件中读取 env 变量名 pubkey_<pubkey_name>
 -C choice        操作：1 修改全部 2 仅添加公钥 0 退出
 -h               显示帮助
EOF
}

while getopts "f:P:R:A:E:M:C:K:N:U:h" opt; do
    case $opt in
        f) env_file="$OPTARG" ;;
        P) port="$OPTARG" ;;
        R) permit_root_login="$OPTARG" ;;
        A) password_auth="$OPTARG" ;;
        E) permit_empty_passwords="$OPTARG" ;;
        M) max_auth_tries="$OPTARG" ;;
        C) choice="$OPTARG" ;;
        U) pubkey_auth="$OPTARG" ;;
        K) public_key="$OPTARG" ;;
        N) pubkey_name="$OPTARG" ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# 加载 env 文件（如果存在）
load_env

# 将 env 中的值覆盖默认值（如果存在）
default_port="${env_vars[ssh_port]:-$default_port}"
default_permit_root_login="${env_vars[ssh_permit_root_login]:-$default_permit_root_login}"
default_password_auth="${env_vars[ssh_password_auth]:-$default_password_auth}"
default_permit_empty_passwords="${env_vars[ssh_permit_empty_passwords]:-$default_permit_empty_passwords}"
default_max_auth_tries="${env_vars[ssh_max_auth_tries]:-$default_max_auth_tries}"
default_pubkey_auth="${env_vars[ssh_pubkey_auth]:-$default_pubkey_auth}"

# 将变量取值顺序：命令行 > env > 默认
port="${port:-$default_port}"
permit_root_login="${permit_root_login:-$default_permit_root_login}"
password_auth="${password_auth:-$default_password_auth}"
permit_empty_passwords="${permit_empty_passwords:-$default_permit_empty_passwords}"
max_auth_tries="${max_auth_tries:-$default_max_auth_tries}"
pubkey_auth="${pubkey_auth:-$default_pubkey_auth}"

# 如果提供了 pubkey_name，从 env 里读对应变量 pubkey_<name>
if [ -z "$public_key" ] && [ -n "$pubkey_name" ]; then
    public_key="${env_vars[pubkey_${pubkey_name}]}"
fi

# 规范化 yes/no 字段
permit_root_login="$(normalize_yesno "$permit_root_login")"
password_auth="$(normalize_yesno "$password_auth")"
permit_empty_passwords="$(normalize_yesno "$permit_empty_passwords")"
pubkey_auth="$(normalize_yesno "$pubkey_auth")"

# 辅助：显示单项配置（从 sshd_config 中获取最后一项）
show_item() {
    local item="$1"
    local value
    # 忽略注释，按最后一条有效配置显示
    value="$(grep -iE "^[[:space:]]*${item}[[:space:]]+" "$ssh_config" 2>/dev/null \
        | tail -n1 \
        | awk '{print $2}')"
    if [ -n "$value" ]; then
        printf "%s %s\n" "$(green "$item")" "$(orange "$value")"
    else
        printf "%s %s\n" "$(green "$item")" "$(red "未设置")"
    fi
}

show_config() {
    yellow "当前 SSH 配置 (从 $ssh_config 读取)"
    for item in Port PermitRootLogin PasswordAuthentication PermitEmptyPasswords MaxAuthTries PubkeyAuthentication; do
        show_item "$item"
    done
    echo
    yellow "Authorized Keys ($authorized_keys)"
    if [ -f "$authorized_keys" ]; then
        sed -n '1,200p' "$authorized_keys" || cat "$authorized_keys"
    else
        orange "未发现 authorized_keys"
    fi
    echo
}

# 安全地修改 SSH 配置：删除原有项（忽略大小写/注释），追加新项
modify_config() {
    local key="$1"
    local value="$2"
    local timestamp
    timestamp="$(date +%s)"
    # 备份一次配置（首次修改时）
    if [ ! -f "${ssh_config}.bak.${timestamp}" ]; then
        cp -a "$ssh_config" "${ssh_config}.bak.${timestamp}" 2>/dev/null || true
    fi
    # 删除匹配项（忽略大小写和前导注释/空白），然后追加
    sed -i "/^[#[:space:]]*${key}[[:space:]]/Id" "$ssh_config"
    echo "${key} ${value}" >> "$ssh_config"
    green "设置 $key = $value"
}

# 添加公钥到 root 的 authorized_keys（会去重）
add_public_key() {
    local key="$1"
    [ -z "$key" ] && { orange "公钥为空，跳过添加"; return; }
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    touch "$authorized_keys"
    chmod 600 "$authorized_keys"
    chown root:root "$authorized_keys"
    # 去除行尾空白并去重插入
    if grep -qxF -- "$key" "$authorized_keys" 2>/dev/null; then
        green "公钥已存在，跳过添加"
    else
        echo "$key" >> "$authorized_keys"
        green "已添加公钥到 $authorized_keys"
    fi
}

# 重启 SSH 服务（先校验配置）
restart_ssh() {
    yellow "校验 SSH 配置..."
    if ! command -v sshd >/dev/null 2>&1; then
        orange "sshd 命令不可用，跳过语法检测（请确认 openssh-server 已安装）"
    else
        if ! sshd -t 2>/dev/null; then
            red "sshd 配置校验失败，请检查 $ssh_config"
            exit 1
        fi
    fi

    yellow "重启 SSH 服务..."
    # 优先尝试 systemctl，如果不可用则尝试 service
    if command -v systemctl >/dev/null 2>&1; then
        # 尝试常见的服务名
        if systemctl list-unit-files | grep -qE '^sshd.service|^ssh.service'; then
            # 优先重启 sshd.service，否则 ssh.service
            if systemctl list-unit-files | grep -q '^sshd.service'; then
                systemctl restart sshd || { red "重启 sshd 失败"; exit 1; }
            else
                systemctl restart ssh || { red "重启 ssh 失败"; exit 1; }
            fi
        else
            # 退回到尝试重启 sshd 或 ssh
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || { red "未能通过 systemctl 重启 SSH 服务"; exit 1; }
        fi
    elif command -v service >/dev/null 2>&1; then
        service sshd restart 2>/dev/null || service ssh restart 2>/dev/null || { red "未能通过 service 重启 SSH 服务"; exit 1; }
    else
        orange "找不到 systemctl/service 命令，请手动重启 SSH 服务"
    fi

    green "SSH 服务已重启（或已请求重启）"
}

# 应用所有参数到 sshd_config 并重启
apply_all() {
    # 参数基本校验（端口）
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        red "端口值无效: $port"
        exit 1
    fi
    # 将值写入配置
    declare -A config_map=(
        ["Port"]="$port"
        ["PermitRootLogin"]="$permit_root_login"
        ["PasswordAuthentication"]="$password_auth"
        ["PermitEmptyPasswords"]="$permit_empty_passwords"
        ["MaxAuthTries"]="$max_auth_tries"
        ["PubkeyAuthentication"]="$pubkey_auth"
    )

    for key in "${!config_map[@]}"; do
        modify_config "$key" "${config_map[$key]}"
    done

    # 添加公钥（如果有）
    add_public_key "$public_key"

    restart_ssh
}

# 展示当前配置与参数摘要
show_config
yellow "当前参数 (优先级: 命令行 > env > 默认)"
echo "port=$port"
echo "permit_root_login=$permit_root_login"
echo "password_auth=$password_auth"
echo "permit_empty_passwords=$permit_empty_passwords"
echo "max_auth_tries=$max_auth_tries"
echo "pubkey_auth=$pubkey_auth"
echo "pubkey_name=${pubkey_name:-<none>}"
echo

# 交互式菜单（如果没有通过 -C 指定 choice）
if [ -z "$choice" ]; then
    yellow "请选择操作"
    echo "1. 修改全部（写入 sshd_config 并重启 ssh）"
    echo "2. 仅添加公钥"
    echo "0. 退出"
    read -rp "请输入选项 [0/1/2]: " choice
fi

case "$choice" in
    1)
        apply_all
        ;;
    2)
        add_public_key "$public_key"
        ;;
    0)
        exit 0
        ;;
    *)
        red "无效选项: $choice"
        exit 1
        ;;
esac

exit 0
