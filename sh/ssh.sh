#!/bin/bash

# version v0.7

# 定义颜色
DEFINE_YELLOW="\033[33m"
DEFINE_BLUE="\033[34m"
DEFINE_GREEN="\033[32m"
DEFINE_RED="\033[31m"
DEFINE_ORANGE="\033[38;5;208m"
DEFINE_RESET="\033[0m"

yellow() {
    echo -e "${DEFINE_YELLOW}$1${DEFINE_RESET}"
}

blue() {
    echo -e "${DEFINE_BLUE}$1${DEFINE_RESET}"
}

green() {
    echo -e "${DEFINE_GREEN}$1${DEFINE_RESET}"
}

orange() {
    echo -e "${DEFINE_ORANGE}$1${DEFINE_RESET}"
}

red() {
    echo -e "${DEFINE_RED}$1${DEFINE_RESET}"
}

# 检查是否以 root 用户运行
if [ "$(id -u)" -ne "0" ]; then
    red "请以 root 用户身份运行此脚本"
    exit 1
fi

# 定义配置文件路径
SSH_CONFIG="/etc/ssh/sshd_config"
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"

# 默认值
DEFAULT_PORT=22
DEFAULT_PERMIT_ROOT_LOGIN="yes"
DEFAULT_PASSWORD_AUTH="yes"
DEFAULT_PERMIT_EMPTY_PASSWORDS="no"
DEFAULT_MAX_AUTH_TRIES=3
NEW_PUBLIC_KEY=""
DEFAULT_PUBKEY_AUTH="yes"

# 处理传入参数
while getopts "P:R:A:E:M:C:K:U:h" opt; do
    case ${opt} in
        P )
            PORT=$OPTARG
            ;;
        R )
            PERMIT_ROOT_LOGIN=$OPTARG
            ;;
        A )
            PASSWORD_AUTH=$OPTARG
            ;;
        E )
            PERMIT_EMPTY_PASSWORDS=$OPTARG
            ;;
        M )
            MAX_AUTH_TRIES=$OPTARG
            ;;
        C )
            CHOICE=$OPTARG
            ;;
        U )
            PUBKEY_AUTH=$OPTARG
            ;;
        K )
            NEW_PUBLIC_KEY=$OPTARG
            ;;
        h )
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -P <port>                  Set the SSH port number"
            echo "  -R <yes|no>                Set PermitRootLogin"
            echo "  -A <yes|no>                Set PasswordAuthentication"
            echo "  -E <yes|no>                Set PermitEmptyPasswords"
            echo "  -M <number>                Set MaxAuthTries"
            echo "  -C <choice>                Set choice for modification"
            echo "  -K <public key>            Add a new public key to authorized_keys"
            echo "  -U <yes|no>                Set PubkeyAuthentication"
            exit 0
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

# 使用默认值，如果没有传入值
PORT=${PORT:-$DEFAULT_PORT}
PERMIT_ROOT_LOGIN=${PERMIT_ROOT_LOGIN:-$DEFAULT_PERMIT_ROOT_LOGIN}
PASSWORD_AUTH=${PASSWORD_AUTH:-$DEFAULT_PASSWORD_AUTH}
PERMIT_EMPTY_PASSWORDS=${PERMIT_EMPTY_PASSWORDS:-$DEFAULT_PERMIT_EMPTY_PASSWORDS}
MAX_AUTH_TRIES=${MAX_AUTH_TRIES:-$DEFAULT_MAX_AUTH_TRIES}
PUBKEY_AUTH=${PUBKEY_AUTH:-$DEFAULT_PUBKEY_AUTH}

# 函数：检查 SSH 配置
check_ssh_config() {
    yellow "当前 SSH 配置检查结果："
    CONFIG_ITEMS=("Port" "PermitRootLogin" "PasswordAuthentication" "PermitEmptyPasswords" "MaxAuthTries" "PubkeyAuthentication")
    for ITEM in "${CONFIG_ITEMS[@]}"; do
        LINES=$(grep -i "^$ITEM\|^#$ITEM" $SSH_CONFIG)
        COUNT=$(echo "$LINES" | wc -l)
        ACTIVE_LINES=$(echo "$LINES" | grep -v '^#')
        ACTIVE_COUNT=$(echo "$ACTIVE_LINES" | wc -l)
        
        # 优先显示未注释的配置
        if [ "$ACTIVE_COUNT" -gt 0 ]; then
            VALUE=$(echo "$ACTIVE_LINES" | head -n 1 | awk '{print $2}')
            if [ "$COUNT" -gt 1 ]; then
                echo -e "$(green "$ITEM") $(orange "$VALUE") $(red "存在多处配置")"
            else
                echo -e "$(green "$ITEM") $(orange "$VALUE")"
            fi
        else
            if [ "$COUNT" -gt 0 ]; then
                VALUE=$(echo "$LINES" | head -n 1 | awk '{print $2}')
                echo -e "$(green "$ITEM") $(orange "$VALUE") #已注释"
            else
                echo -e "$(green "$ITEM") $(orange "未设定")"
            fi
        fi
    done
    yellow "Public Key:"
    if [ -f "$AUTHORIZED_KEYS" ]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            orange "$line"
        done < "$AUTHORIZED_KEYS"
    else
        echo "$(orange "No authorized keys file found.")"
    fi
    echo ""
}

# 函数：修改 SSH 配置
modify_config() {
    local OPTION=$1
    local VALUE=$2
    local CONFIG_FILE=$SSH_CONFIG

    # 检查配置文件中该选项的所有出现（包括注释和未注释的）
    local EXISTS=$(grep -i "^$OPTION\|^#$OPTION" $CONFIG_FILE)

    if [ -z "$EXISTS" ]; then
        # 如果没有找到任何相关配置项，确保文件末尾有一个换行符后添加新的配置项
        # 使用 sed 在文件末尾加入换行符（如果不存在的话）
        echo >> $CONFIG_FILE
        echo "$OPTION $VALUE" >> $CONFIG_FILE
    else
        # 找到第一个出现的配置项（无论是否被注释）
        local FIRST_OCCURRENCE=$(grep -i "^$OPTION\|^#$OPTION" $CONFIG_FILE | head -n 1)

        # 删除所有同名配置项
        sed -i "/^$OPTION\|^#$OPTION/d" $CONFIG_FILE

        # 替换第一个出现的配置项的值，并确保它是激活状态（删除前面的注释符号，如果有）
        local NEW_LINE=$(echo "$FIRST_OCCURRENCE" | sed -e "s/^#*\($OPTION\).*$/\1 $VALUE/")

        # 将更新后的第一个配置项添加回配置文件
        echo "$NEW_LINE" >> $CONFIG_FILE
    fi
}

# 函数：添加公钥
add_public_key() {
    local KEY=$1
    if [ -n "$KEY" ]; then
        # 确保 .ssh 目录存在
        if [ ! -d "/root/.ssh" ]; then
            mkdir -p "/root/.ssh"
            chmod 700 "/root/.ssh"
            echo "已自动创建 .ssh 目录"
        fi
        # 确保 authorized_keys 文件存在
        if [ ! -f "$AUTHORIZED_KEYS" ]; then
            touch "$AUTHORIZED_KEYS"
            chmod 600 "$AUTHORIZED_KEYS"
            chown root:root "$AUTHORIZED_KEYS"
            echo "已自动创建 authorized_keys 文件"
        fi
        echo "$KEY" >> "$AUTHORIZED_KEYS"
    fi
}


# 函数：重启 SSH 服务
restart_ssh_service() {
    echo -e "$(yellow "正在测试 SSH 配置...")"
    if sshd -t; then
        echo -e "$(yellow "SSH 配置无误，正在重启 SSH 服务...")"
        sudo systemctl daemon-reload
        sudo systemctl restart ssh
        if [ $? -eq 0 ]; then
            echo -e "$(green "SSH 服务重启成功")"
        else
            echo -e "$(red "SSH 服务重启失败，请检查错误")"
            exit 1
        fi
    else
        echo -e "$(red "SSH 配置测试失败，请检查配置文件。")"
        exit 1
    fi
}

# 执行检查函数
check_ssh_config

# 打印传入值
yellow "当前传入值："
echo -n "$(blue "Port: ")"
echo "$(orange "$PORT")"
echo -n "$(blue "PermitRootLogin: ")"
echo "$(orange "$PERMIT_ROOT_LOGIN")"
echo -n "$(blue "PasswordAuthentication: ")"
echo "$(orange "$PASSWORD_AUTH")"
echo -n "$(blue "PermitEmptyPasswords: ")"
echo "$(orange "$PERMIT_EMPTY_PASSWORDS")"
echo -n "$(blue "MaxAuthTries: ")"
echo "$(orange "$MAX_AUTH_TRIES")"
echo -n "$(blue "Public Key : ")"
echo "$(orange "$NEW_PUBLIC_KEY")"
echo -n "$(blue "PubkeyAuthentication: ")"
echo "$(orange "$PUBKEY_AUTH")"
echo ""
echo ""


# 选择修改
if [ -z "$CHOICE" ]; then
    echo ""
    yellow "请选择要修改的选项："
    echo "$(green "1)") 根据传入值修改全部"
    echo "$(green "2)") 修改 Port"
    echo "$(green "3)") 修改 PermitRootLogin"
    echo "$(green "4)") 修改 PasswordAuthentication"
    echo "$(green "5)") 修改 PermitEmptyPasswords"
    echo "$(green "6)") 修改 MaxAuthTries"
    echo "$(green "7)") 添加公钥"
    echo "$(green "8)") 修改 PubkeyAuthentication"
    echo "$(green "0)") 退出脚本"
    read -p "$(blue "请输入选项: ")" CHOICE
fi

case $CHOICE in
    1)
        modify_config "Port" "$PORT"
        modify_config "PermitRootLogin" "$PERMIT_ROOT_LOGIN"
        modify_config "PasswordAuthentication" "$PASSWORD_AUTH"
        modify_config "PermitEmptyPasswords" "$PERMIT_EMPTY_PASSWORDS"
        modify_config "MaxAuthTries" "$MAX_AUTH_TRIES"
        modify_config "PubkeyAuthentication" "$PUBKEY_AUTH"
        if [ -n "$NEW_PUBLIC_KEY" ]; then
            add_public_key "$NEW_PUBLIC_KEY"
        fi
        
        restart_ssh_service
        ;;
    2)
        echo "请输入新的 Port 值 (默认 $DEFAULT_PORT):"
        read NEW_PORT
        NEW_PORT=${NEW_PORT:-$DEFAULT_PORT}
        modify_config "Port" "$NEW_PORT"
        restart_ssh_service
        ;;
    3)
        echo "请输入新的 PermitRootLogin 值 (yes/no, 默认 $DEFAULT_PERMIT_ROOT_LOGIN):"
        read NEW_PERMIT_ROOT_LOGIN
        NEW_PERMIT_ROOT_LOGIN=${NEW_PERMIT_ROOT_LOGIN:-$DEFAULT_PERMIT_ROOT_LOGIN}
        modify_config "PermitRootLogin" "$NEW_PERMIT_ROOT_LOGIN"
        restart_ssh_service
        ;;
    4)
        echo "请输入新的 PasswordAuthentication 值 (yes/no, 默认 $DEFAULT_PASSWORD_AUTH):"
        read NEW_PASSWORD_AUTH
        NEW_PASSWORD_AUTH=${NEW_PASSWORD_AUTH:-$DEFAULT_PASSWORD_AUTH}
        modify_config "PasswordAuthentication" "$NEW_PASSWORD_AUTH"
        restart_ssh_service
        ;;
    5)
        echo "请输入新的 PermitEmptyPasswords 值 (yes/no, 默认 $DEFAULT_PERMIT_EMPTY_PASSWORDS):"
        read NEW_PERMIT_EMPTY_PASSWORDS
        NEW_PERMIT_EMPTY_PASSWORDS=${NEW_PERMIT_EMPTY_PASSWORDS:-$DEFAULT_PERMIT_EMPTY_PASSWORDS}
        modify_config "PermitEmptyPasswords" "$NEW_PERMIT_EMPTY_PASSWORDS"
        restart_ssh_service
        ;;
    6)
        echo "请输入新的 MaxAuthTries 值 (数字, 默认 $DEFAULT_MAX_AUTH_TRIES):"
        read NEW_MAX_AUTH_TRIES
        NEW_MAX_AUTH_TRIES=${NEW_MAX_AUTH_TRIES:-$DEFAULT_MAX_AUTH_TRIES}
        modify_config "MaxAuthTries" "$NEW_MAX_AUTH_TRIES"
        restart_ssh_service
        ;;
    7)
        echo "请输入新的公钥值:"
        read NEW_PUBLIC_KEY
        add_public_key "$NEW_PUBLIC_KEY"
        ;;
    8)
        echo "请输入新的 PubkeyAuthentication 值 (yes/no, 默认 $DEFAULT_PUBKEY_AUTH):"
        read NEW_PUBKEY_AUTH
        NEW_PUBKEY_AUTH=${NEW_PUBKEY_AUTH:-$DEFAULT_PUBKEY_AUTH}
        modify_config "PubkeyAuthentication" "$NEW_PUBKEY_AUTH"
        restart_ssh_service
        ;;
    0)
        echo "退出脚本"
        exit 0
        ;;
    *)
        echo "无效的选项"
        exit 1
        ;;
esac
