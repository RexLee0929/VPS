#!/bin/bash

v0.5
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

# 处理传入参数
while getopts "P:R:A:E:M:C:K:h" opt; do
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

# 函数：检查 SSH 配置
check_ssh_config() {
    yellow "当前 SSH 配置检查结果："
    CONFIG_ITEMS=("Port" "PermitRootLogin" "PasswordAuthentication" "PermitEmptyPasswords" "MaxAuthTries")
    for ITEM in "${CONFIG_ITEMS[@]}"; do
        LINE=$(grep -i "^$ITEM" $SSH_CONFIG | grep -v '^#')
        COMMENT=$(grep -i "^#$ITEM" $SSH_CONFIG)
        if [ -z "$LINE" ]; then
            if [ -n "$COMMENT" ]; then
                VALUE=$(echo "$COMMENT" | awk '{print $2}')
                echo -e "$(green "$ITEM") $(orange "$VALUE") #已注释"
            else
                echo -e "$(green "$ITEM") $(orange "未设定")"
            fi
        else
            VALUE=$(echo "$LINE" | awk '{print $2}')
            echo -e "$(green "$ITEM") $(orange "$VALUE")"
        fi
    done
    echo ""
	yellow "Public Key:"
	if [ -f "$AUTHORIZED_KEYS" ]; then
	    while IFS= read -r line
	    do
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
    local LINE
    local COMMENT

    LINE=$(grep -i "^$OPTION" $SSH_CONFIG | grep -v '^#')
    COMMENT=$(grep -i "^#$OPTION" $SSH_CONFIG)
    
    if [ -n "$LINE" ]; then
        # 如果配置项已经存在且未注释
        sed -i "s/^$OPTION.*/$OPTION $VALUE/" $SSH_CONFIG
    elif [ -n "$COMMENT" ]; then
        # 如果配置项被注释掉
        sed -i "s/^#$OPTION.*/$OPTION $VALUE/" $SSH_CONFIG
    else
        # 如果配置项不存在
        echo "$OPTION $VALUE" >> $SSH_CONFIG
    fi
}

# 函数：添加公钥
add_public_key() {
    local KEY=$1
    if [ -n "$KEY" ]; then
        echo "$KEY" >> "$AUTHORIZED_KEYS"
    fi
}

# 函数：重启 SSH 服务
restart_ssh_service() {
    echo -e "$(blue "正在重启 SSH 服务...")"
    systemctl restart ssh
    if [ $? -eq 0 ]; then
        echo -e "$(green "SSH 服务重启成功")"
    else
        echo -e "$(red "SSH 服务重启失败，请检查错误")"
        exit 1
    fi
}

# 执行检查函数
check_ssh_config

# 打印传入值
echo "当前传入值："
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
echo ""
echo -n "$(blue "Public Key : ")"
echo "$(orange "$NEW_PUBLIC_KEY")"


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
    0)
        echo "退出脚本"
        exit 0
        ;;
    *)
        echo "无效的选项"
        exit 1
        ;;
esac
