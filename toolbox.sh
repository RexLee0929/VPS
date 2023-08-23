#by Rex Lee


##脚本所用到的颜色

# 颜色函数
    red(){
        echo -e "\033[31m\033[01m$1\033[0m"
    }
    green(){
        echo -e "\033[32m\033[01m$1\033[0m"
    }
    yellow(){
        echo -e "\033[33m\033[01m$1\033[0m"
    }
    blue(){
        echo -e "\033[34m\033[01m$1\033[0m"
    }
    orange(){
        echo -e "\033[38;5;208m\033[01m$1\033[0m"
    }
    purple(){
        echo -e "\033[38;5;5m$1\033[0m"
    }

    black(){
        echo -e "\033[38;5;0m$1\033[0m"
    }

# 系统设置
## BBR加速
function bbr_management(){
    # 确保脚本在任何命令失败时停止
    set -e
    
    # 检查wget是否已安装
    if ! command -v wget &> /dev/null; then
        echo 
        red " Error: wget is not installed. Please install it first. "
        return 1
    fi

    # 使用wget下载脚本
    if ! wget -4 -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"; then
        echo 
        red " Error: Failed to download the script. Contact Rex to update the script URL "
        return 1
    fi
    
    # 使脚本可执行
    chmod +x tcp.sh

    # 执行脚本
    ./tcp.sh

    # 可选: 执行后删除脚本
    # rm -f tcp.sh

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    system_menu
}
## 设置时区
function swap_management(){
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " ============设置时区=============== "
    green " 1. 设置时区为上海 "
    green " 2. 设置时区为东京 "
    green " 3. 设置时区为纽约 "
    green " 4. 设置时区为洛杉矶 "
    green " 5. 设置时区为伦敦 "
    green " 6. 设置时区为巴黎 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回系统设置菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # 确保用户具有必要的权限
    if [ "$(id -u)" != "0" ]; then
        echo 
        red " 错误: 此功能需要以 root 或 sudo 身份运行. "
        return 1
    fi

    # 检查timedatectl是否可用
    if ! command -v timedatectl &> /dev/null; then
        echo 
        red " 错误: 此系统不支持 timedatectl 命令. "
        return 1
    fi

    case "$menuNumberInput" in
        1 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Asia/Shanghai'
            if [ "$current_timezone" == "$target_timezone" ]; then
                purple " 您已经设置过时区为 $target_timezone 了 "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone. 已将时区设置为 $target_timezone "
            fi
        ;;
        2 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Asia/Tokyo'
            if [ "$current_timezone" == "$target_timezone" ]; then
                purple " 您已经设置过时区为 $target_timezone 了 "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone. 已将时区设置为 $target_timezone "
            fi
        ;;
        3 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='America/New_York'
            if [ "$current_timezone" == "$target_timezone" ]; then
                purple " 您已经设置过时区为 $target_timezone 了 "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone. 已将时区设置为 $target_timezone "
            fi
        ;;
        4 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='America/Los_Angeles'
            if [ "$current_timezone" == "$target_timezone" ]; then
                purple " 您已经设置过时区为 $target_timezone 了 "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone. 已将时区设置为 $target_timezone "
            fi
        ;;
        5 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Europe/London'
            if [ "$current_timezone" == "$target_timezone" ]; then
                purple " 您已经设置过时区为 $target_timezone 了 "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone. 已将时区设置为 $target_timezone "
            fi
        ;;
        6 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Europe/Paris'
            if [ "$current_timezone" == "$target_timezone" ]; then
                purple " 您已经设置过时区为 $target_timezone 了 "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone. 已将时区设置为 $target_timezone "
            fi
        ;;
        0 )
            # 返回系统菜单
            system_menu
            return 0
        ;;
        * )
            red " 无效的选择,请重新输入 "
            red " 两秒后重新选择返回 "
            sleep 2s
            swap_management
        ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    swap_management
}
## 设置swap
function swap_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    blue " 代码参考: https://github.com/spiritLHLS "
    yellow " ============设置swap=============== "
    green " 1. 设置swap为1G "
    green " 2. 设置swap为2G "
    green " 3. 设置swap为4G "
    green " 4. 自定义swap大小 "
    green " 5. 删除swap "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回系统设置菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # root权限检查
    if [[ $EUID -ne 0 ]]; then
        red " 错误: 此脚本必须以 root 权限运行 "
        exit 1
    fi

    # 检测ovz
    if [[ -d "/proc/vz" ]]; then
        red " 您的 VPS 基于 OpenVZ,不支持 "
        exit 1
    fi

    add_swap() {
        local swapsize=$1
        # 检查是否存在swapfile
        grep -q "swapfile" /etc/fstab

        # 如果不存在将为其创建swap
        if [ $? -ne 0 ]; then
            green " swapfile 未发现,正在为其创建 swapfile "
            fallocate -l ${swapsize}M /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap defaults 0 0' >> /etc/fstab
            green " swap 创建成功,并查看信息: "
            cat /proc/swaps
            cat /proc/meminfo | grep Swap
        else
            red " swapfile 已存在, swap 设置失败,请先删除当前 swap 后重新设置 "
        fi
    }

    del_swap() {
        # 检查是否存在swapfile
        grep -q "swapfile" /etc/fstab

        # 如果存在就将其移除
        if [ $? -eq 0 ]; then
            green " swapfile已发现,正在将其移除... "
            sed -i '/swapfile/d' /etc/fstab
            echo "3" > /proc/sys/vm/drop_caches
            swapoff -a
            rm -f /swapfile
            green " swap 已删除 "
        else
            red " swapfile 未发现, swap 删除失败 "
        fi
    }

    case "$menuNumberInput" in
        1)
            add_swap 1024
            ;;
        2)
            add_swap 2048
            ;;
        3)
            add_swap 4096
            ;;
        4)
            green " 请输入需要添加的 swap 大小(单位: MB): "
            read -p " 请输入 swap 数值: " custom_swap_size
            add_swap $custom_swap_size
            ;;
        5)
            del_swap
            ;;
        0)
            # 返回系统菜单
            system_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2s
            swap_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    swap_management
}
## IPv4/IPv6优先级调整
function network_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    green " =======IPv4/IPv6优先级调整=========== "
    yellow " 请为服务器设置优先使用 IPv4 还是 IPv6 : "
    echo
    green " 1. 优先使用 IPv4 "
    green " 2. 优先使用 IPv6 "
    green " 3. 删除优先使用 IPv4 或 IPv6 的设置, 还原为系统默认配置 "
    green " 4. 验证 IPv4 或 IPv6 的优先级 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================== "
    green " 0. 返回系统设置菜单 "
    echo
    read -p " 您的选择是: " isnetwork_managementInput
    case $isnetwork_managementInput in
        1)
            # 检查是否已经设置了 IPv4 优先
            if grep -qE "^[^#]*precedence ::ffff:0:0/96  100" /etc/gai.conf; then
                purple " 您已经设置过优先使用 IPv4 了 "
            else
                if grep -qE "^[^#]*label 2002::/16   2" /etc/gai.conf; then
                    purple " 您已经设置过了 IPv6 优先, 本次清除了 IPv6 优先的设置 "
                    sed -i '/label 2002::\/16   2/d' /etc/gai.conf
                fi
                # 设置 IPv4 优先
                echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
                purple " 已经成功设置为 IPv4 优先 "
            fi
            ;;
        2)
            # 检查是否已经设置了 IPv6 优先
            if grep -qE "^[^#]*label 2002::/16   2" /etc/gai.conf; then
                purple " 您已经设置过优先使用 IPv6 了 "
            else
                if grep -qE "^[^#]*precedence ::ffff:0:0/96  100" /etc/gai.conf; then
                    purple " 您已经设置过了 IPv4 优先, 本次清除了 IPv4 优先的设置 "
                    sed -i '/precedence ::ffff:0:0\/96  100/d' /etc/gai.conf
                fi
                # 设置 IPv6 优先
                echo "label 2002::/16   2" >> /etc/gai.conf
                purple " 已经成功设置为 IPv6 优先 "
            fi
            ;;
        3)
            # 删除 IPv4 和 IPv6 的优先设置
            sed -i '/precedence ::ffff:0:0\/96  100/d' /etc/gai.conf
            sed -i '/label 2002::\/16   2/d' /etc/gai.conf
            echo
            blue " VPS服务器已删除 IPv4 或 IPv6 优先使用的设置, 还原为系统默认配置 "
            ;;
        4)
            # 验证 IPv4 或 IPv6 的优先级
            clear
            blue " Rex Lee's ToolBox "
            blue " GitHub: https://github.com/RexLee0929 "
            green " =======IPv4/IPv6优先级调整=========== "
            green " ====验证 IPv4 或 IPv6 的优先级======= "
            echo
            yellow " 验证 IPv4 或 IPv6 的优先级测试, 命令: curl ip.p3terx.com "
            echo
            curl ip.p3terx.com
            echo
            green " 上面信息显示: "
            green " 如果是IPv4地址->则VPS服务器已设置为优先使用 IPv4 "
            green " 如果是IPv6地址->则VPS服务器已设置为优先使用 IPv6 "
            green " ===================================== "
            echo
            ;;
        0)
            # 返回系统菜单
            system_menu
            return 0
            ;;
        *)
            red " 无效的选择,请重新输入 "
            red " 两秒后自动返回 "
            sleep 2s
            network_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    network_management
}

# 软件
## wget, curl 和 git
function install_wget_curl_git() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " =============工具菜单=============== "
    green " 1. 安装 wget, curl, git "
    green " 2. 安装 wget "
    green " 3. 安装 curl "
    green " 4. 安装 git "
    black " 5. 卸载 wget, curl, git "
    black " 6. 卸载 wget "
    black " 7. 卸载 curl "
    black " 8. 卸载 git "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue " 检测到您的系统为: $OS "

    case "$menuNumberInput" in
        1)
            if command -v wget &> /dev/null && command -v curl &> /dev/null && command -v git &> /dev/null; then
                purple " 您已经安装过 wget, curl 和 git 了 "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt update
                    sudo apt install -y wget curl git
                    ;;
                centos|redhat)
                    sudo yum install -y wget curl git
                    ;;
                arch)
                    sudo pacman -S wget curl git
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            blue " wget, curl 和 git 安装完成 "
            ;;
        2)
            if command -v wget &> /dev/null; then
                purple " 您已经安装过 wget "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt install -y wget
                    ;;
                centos|redhat)
                    sudo yum install -y wget
                    ;;
                arch)
                    sudo pacman -S wget
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            blue " wget 安装完成 "
            ;;
        3)
            if command -v curl &> /dev/null; then
                purple " 您已经安装过 curl "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt install -y curl
                    ;;
                centos|redhat)
                    sudo yum install -y curl
                    ;;
                arch)
                    sudo pacman -S curl
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            blue "curl 安装完成 "
            ;;
        4)
            if command -v git &> /dev/null; then
                purple " 您已经安装过git "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt install -y git
                    ;;
                centos|redhat)
                    sudo yum install -y git
                    ;;
                arch)
                    sudo pacman -S git
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            blue " git 安装完成 "
            ;;
        5)
            if ! command -v wget &> /dev/null || ! command -v curl &> /dev/null || ! command -v git &> /dev/null; then
                blue " 您没有安装 wget, curl 或 git 中的至少一个 "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt remove -y wget curl git
                    ;;
                centos|redhat)
                    sudo yum remove -y wget curl git
                    ;;
                arch)
                    sudo pacman -R wget curl git
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            black " wget, curl 和 git 卸载完成 "
            ;;
        6)
            if ! command -v wget &> /dev/null; then
                blue " 您没有安装 wget "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt remove -y wget
                    ;;
                centos|redhat)
                    sudo yum remove -y wget
                    ;;
                arch)
                    sudo pacman -R wget
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            black " wget 卸载完成 "
            ;;
        7)
            if ! command -v curl &> /dev/null; then
                blue " 您没有安装 curl "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt remove -y curl
                    ;;
                centos|redhat)
                    sudo yum remove -y curl
                    ;;
                arch)
                    sudo pacman -R curl
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            black " curl 卸载完成 "
            ;;
        8)
            if ! command -v git &> /dev/null; then
                blue " 您没有安装 git "
                red " 两秒后自动返回 "
                sleep 2
                install_wget_curl_git
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt remove -y git
                    ;;
                centos|redhat)
                    sudo yum remove -y git
                    ;;
                arch)
                    sudo pacman -R git
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    install_wget_curl_git
                    return
                    ;;
            esac
            black " git 卸载完成 "
            ;;
        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2s
            install_wget_curl_git
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    install_wget_curl_git
}
## nano
function nano_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============Nano菜单=============== "
    green " 1. 安装 Nano "
    green " 2. 使用 Nano 打开文件 "
    black " 3. 卸载 Nano "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    case "$menuNumberInput" in
        1)
            if command -v nano &> /dev/null; then
                purple " 您已经安装过nano了 "
                red " 两秒后自动返回 "
                sleep 2
                nano_management
                return
            fi
            
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS=$ID
            else
                OS=$(uname -s)
            fi

            blue " 检测到您的系统为: $OS "

            case $OS in
                ubuntu|debian)
                    blue " 将为您执行 $OS 下的 nano 安装 "
                    sudo apt update
                    sudo apt install -y nano
                    ;;
                centos|redhat)
                    blue " 将为您执行 $OS 下的 nano 安装 "
                    sudo yum install -y nano
                    ;;
                arch)
                    blue " 将为您执行 $OS 下的 nano 安装 "
                    sudo pacman -S nano
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    nano_management
                    return
                    ;;
            esac
            blue " nano 安装完成 "
            ;;
        2)
            if ! command -v nano &> /dev/null; then
                red " 您没有安装 nano 请先安装. "
                red " 两秒后自动返回 "
                sleep 2
                nano_management
                return
            fi
            read -p " 请输入您要使用 nano 打开的文件路径: " filepath
            nano "$filepath"
            ;;
        3)
            if ! command -v nano &> /dev/null; then
                red " 您没有安装 nano "
                red " 两秒后自动返回 "
                sleep 2
                nano_management
                return
            fi
            
            if [ -z "$OS " ]; then
                red " 无法确定操作系统 "
                red " 两秒后自动返回 "
                sleep 2
                nano_management
                return
            fi
            
            case $OS in
                ubuntu|debian)
                    black " 将为您执行 $OS 下的 nano 卸载 "
                    sudo apt remove -y nano
                    ;;
                centos|redhat)
                    black " 将为您执行 $OS 下的 nano 卸载 "
                    sudo yum remove -y nano
                    ;;
                arch)
                    black " 将为您执行 $OS 下的 nano 卸载 "
                    sudo pacman -R nano
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    nano_management
                    return
                    ;;
            esac
            black " nano 卸载完成 "
            ;;
        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2s
            nano_management
            return
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    nano_management
}
## screen
function screen_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============Screen菜单=============== "
    green " 1. 安装 Screen "
    green " 2. 使用 Screen 创建新会话 "
    green " 3. 使用 Screen 运行指令 "
    green " 4. 查看 Screen 会话 "
    green " 5. 删除 Screen 会话 "
    green " 6. 删除所有的 screen 会话 "
    black " 7. 卸载 Screen "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回系统设置菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    case "$menuNumberInput" in
        1)
            if command -v screen &> /dev/null; then
                purple " 您已经安装过 screen 了 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi
            
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS=$ID
            else
                OS=$(uname -s)
            fi

            blue " 检测到您的系统为: $OS "

            case $OS in
                ubuntu|debian)
                    blue " 将为您执行 $OS 下的 screen 安装 "
                    sudo apt update
                    sudo apt install -y screen
                    ;;
                centos|redhat)
                    blue " 将为您执行 $OS 下的 screen 安装 "
                    sudo yum install -y screen
                    ;;
                arch)
                    blue " 将为您执行 Arch Linux 下的 screen 安装 "
                    sudo pacman -S screen
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    nano_management
                    return
                    ;;
            esac
            blue " screen 安装完成 "
            ;;
        2)
            if ! command -v screen &> /dev/null; then
                red " 没有安装 screen 请先安装 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi
            read -p " 请输入新会话的名称: " session_name
            screen -S $session_name
            ;;
        3)
            if ! command -v screen &> /dev/null; then
                red " 没有安装 screen 请先安装 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi
            read -p " 请输入您想在 screen 会话中执行的命令: " user_command
            read -p " 请输入您希望的 screen 会话名称: " session_name
            screen -dmS "$session_name" bash -c "$user_command; exec bash"
            blue " 已在新的screen会话 $session_name 中启动您的命令 "
            ;; 
        4)
            # 检查 screen 命令是否存在
            if ! command -v screen &> /dev/null; then
                red " 没有安装 screen 请先安装 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi

            # 使用 screen -ls 获取所有的 screen 会话
            sessions=$(screen -ls | grep "Detached" | awk '{print $1}')

            # 检查是否有可用的会话
            if [ -z "$sessions" ]; then
                red " 当前没有运行的screen会话 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi

            echo " 当前运行的 screen 会话: "
            counter=1
            declare -A session_map
            while IFS= read -r line; do
                echo "$counter. $line"
                session_map[$counter]=$line
                ((counter++))
            done <<< "$sessions"

            read -p " 请输入编号选择一个会话: " choice

            if [ -n "${session_map[$choice]}" ]; then
                screen -r "${session_map[$choice]}"
            else
                red " 无效的选择 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi
            ;;
        5)
            # 检查 screen 命令是否存在
            if ! command -v screen &> /dev/null; then
                red " 没有安装 screen 请先安装 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi

            # 使用 screen -ls 获取所有的 screen 会话
            sessions=$(screen -ls | grep "Detached" | awk '{print $1}')

            # 检查是否有可用的会话
            if [ -z "$sessions" ]; then
                red " 当前没有运行的 screen 会话 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi

            echo " 当前运行的 screen 会话: "
            counter=1
            declare -A session_map
            while IFS= read -r line; do
                echo "$counter. $line"
                session_map[$counter]=$line
                ((counter++))
            done <<< "$sessions"

            read -p " 请输入编号选择一个会话进行删除: " choice

            if [ -n "${session_map[$choice]}" ]; then
                screen -X -S "${session_map[$choice]}" quit
                blue " 已删除会话: ${session_map[$choice]} "
                read -p " 是否继续删除其他会话? (y/n)默认y: " continue_delete
                if [ "$continue_delete" == "y" ]; then
                    # 继续删除
                    return
                else
                    red " 您选择拒绝继续删除 screen 会话 "
                    red " 两秒后自动返回 "
                    sleep 2
                    # 返回 screen_management
                    screen_management
                fi
            else
                red " 无效的选择 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi
            ;;
        6)
            # 检查 screen 命令是否存在
            if ! command -v screen &> /dev/null; then
                red " 没有安装 screen 请先安装 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi

            # 使用 screen -ls 获取所有的 screen 会话
            sessions=$(screen -ls | grep "Detached" | awk '{print $1}')

            # 检查是否有可用的会话
            if [ -z "$sessions" ]; then
                red " 当前没有运行的 screen 会话 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi

            read -p " 确定要删除所有的 screen 会话吗？(y/n)默认n: " confirm_delete_all

            if [ "$confirm_delete_all" == "y" ]; then
                while IFS= read -r session; do
                    screen -X -S "$session" quit
                done <<< "$sessions"
                blue " 已删除所有的 screen 会话 "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
            else
                red " 您选择取消删除所有的 screen 会话 "
                red " 两秒后自动返回 "
                sleep 2
                # 返回 screen_management
                screen_management
            fi
            ;;
        7)
            if ! command -v screen &> /dev/null; then
                red " 您没有安装 screen "
                red " 两秒后自动返回 "
                sleep 2
                screen_management
                return
            fi
            case $OS in
                ubuntu|debian)
                    black " 将为您执行 $OS 下的 screen 卸载 "
                    sudo apt remove -y screen
                    ;;
                centos|redhat)
                    black " 将为您执行 $OS 下的 screen 卸载 "
                    sudo yum remove -y screen
                    ;;
                arch)
                    black " 将为您执行 $OS 下的 screen 卸载 "
                    sudo pacman -R screen
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    nano_management
                    return
                    ;;
            esac
            black " screen 卸载完成 "
            ;;
        0)
            # 返回安装包菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2s
            screen_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    screen_management
}
## unzip
function unzip_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============unzip菜单=============== "
    green " 1. 安装 unzip "
    green " 2. 使用 unzip 解压文件 "
    green " 3. 使用 zip 压缩文件夹 "
    green " 4. 批量使用 unzip 解压文件 "
    green " 5. 批量使用 zip 压缩文件夹 "
    green " 6. 使用 screen 执行 zip 批量解压 "
    green " 7. 使用 screen 执行 zip 批量压缩 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue " 检测到您的系统为: $OS "

    case "$menuNumberInput" in
        1)
            if command -v unzip &> /dev/null; then
                purple " 您已经安装过 unzip 了 "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    blue " 将为您执行 $OS 下的 unzip 安装 "
                    sudo apt update
                    sudo apt install -y unzip
                    ;;
                centos|redhat)
                    blue " 将为您执行 $OS 下的 unzip 安装 "
                    sudo yum install -y unzip
                    ;;
                arch)
                    blue " 将为您执行 $OS 下的 unzip 安装 "
                    sudo pacman -S unzip
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2s
                    unzip_management
                    return
                    ;;
            esac
            blue " unzip 安装完成 "
            ;;

        2)
            if ! command -v unzip &> /dev/null; then
                red " 您没有安装 unzip "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
            fi
            read -p " 请输入您要解压的zip文件路径: " zipfile
            read -p " 请输入解压到的路径: " destpath
            mkdir -p "$destpath"
            read -p " 请输入密码 (如果不想设置密码,请直接按 Enter ): " password
            if [ -z "$password" ]; then
                unzip "$zipfile" -d "$destpath"
            else
                unzip -P "$password" "$zipfile" -d "$destpath"
            fi
            ;;
        3)
            if ! command -v zip &> /dev/null; then
                red " 您没有安装 zip "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
            fi
            read -p " 请输入您要压缩的文件夹路径: " folderpath
            read -p " 请输入压缩包的存放路径: " destpath
            mkdir -p "$destpath"
            read -p " 请输入密码 (如果不想设置密码,请直接按 Enter ): " password
            foldername=$(basename "$folderpath")
            # 更改到文件夹的上级目录
            cd "$(dirname "$folderpath")"
            if [ -z "$password" ]; then
                zip -r "$destpath/$foldername.zip" "$foldername"
            else
                zip -r -P "$password" "$destpath/$foldername.zip" "$foldername"
            fi
            ;;

        4)
            if ! command -v unzip &> /dev/null; then
                red " 您没有安装 unzip "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
            fi
            read -p " 请输入包含zip文件的目录路径: " dirpath
            read -p " 请输入要解压到的目标路径: " targetpath
            mkdir -p "$targetpath"
            read -p " 所有文件是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                for z in "$dirpath"/*.zip; do
                    if [ -z "$unified_password" ]; then
                        unzip "$z" -d "$targetpath"
                    else
                        unzip -P "$unified_password" "$z" -d "$targetpath"
                    fi
                done
            else
                for z in "$dirpath"/*.zip; do
                    read -p " 为 $z 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                    if [ -z "$individual_password" ]; then
                        unzip "$z" -d "$targetpath"
                    else
                        unzip -P "$individual_password" "$z" -d "$targetpath"
                    fi
                done
            fi
            ;;

        5)
            if ! command -v zip &> /dev/null; then
                red " 您没有安装 zip "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
            fi

            read -p " 请输入包含文件夹的目录路径: " dirpath
            read -p " 请输入压缩包的存放路径: " destpath
            mkdir -p "$destpath"
            read -p " 所有文件夹是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            # 进入到dirpath所在的目录
            pushd "$dirpath" > /dev/null

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                for dir in *; do
                    if [ -d "$dir" ]; then
                        if [ -z "$unified_password" ]; then
                            zip -r "$destpath/$dir.zip" "$dir"
                        else
                            zip -r -P "$unified_password" "$destpath/$dir.zip" "$dir"
                        fi
                    fi
                done
            else
                for dir in *; do
                    if [ -d "$dir" ]; then
                        read -p " 为 $dir 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                        if [ -z "$individual_password" ]; then
                            zip -r "$destpath/$dir.zip" "$dir"
                        else
                            zip -r -P "$individual_password" "$destpath/$dir.zip" "$dir"
                        fi
                    fi
                done
            fi

            # 返回原始目录
            popd > /dev/null
            ;;

        6)
            # 批量解压在screen会话中
            if ! command -v unzip &> /dev/null || ! command -v screen &> /dev/null; then
                red " 您没有安装 unzip 或 screen "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
            fi
            read -p " 请输入包含 zip 文件的目录路径: " dirpath
            read -p " 请输入要解压到的目标路径: " targetpath
            mkdir -p "$targetpath"
            read -p " 所有文件是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                if [ -z "$unified_password" ]; then
                    cmd= "for z in $dirpath/*.zip; do unzip \$z -d $targetpath; done"
                else
                    cmd= "for z in $dirpath/*.zip; do unzip -P '$unified_password' \$z -d $targetpath; done"
                fi
                screen -dmS unzip_session bash -c "$cmd"
            else
                for z in "$dirpath"/*.zip; do
                    read -p " 为 $z 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                    if [ -z "$individual_password" ]; then
                        cmd= "unzip $z -d $targetpath"
                    else
                        cmd= "unzip -P '$individual_password' $z -d $targetpath"
                    fi
                    screen -dmS unzip_session bash -c "$cmd"
                done
            fi
            blue " 已在新的 screen 会话 unzip_session 中启动解压任务 "
            ;;

        7)
            # 批量压缩在screen会话中
            if ! command -v zip &> /dev/null || ! command -v screen &> /dev/null; then
                red " 您没有安装 zip 或 screen "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
            fi

            read -p " 请输入包含文件夹的目录路径: " dirpath
            read -p " 请输入压缩包的存放路径: " destpath
            mkdir -p "$destpath"
            read -p " 所有文件夹是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            pushd "$dirpath" > /dev/null

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                if [ -z "$unified_password" ]; then
                    cmd= "for d in *; do if [ -d \$d ]; then zip -r $destpath/\$d.zip \$d; fi; done"
                else
                    cmd= "for d in *; do if [ -d \$d ]; then zip -r -P '$unified_password' $destpath/\$d.zip \$d; fi; done"
                fi
                screen -dmS zip_session bash -c "$cmd"
            else
                for d in *; do
                    if [ -d "$d" ]; then
                        read -p " 为 $d 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                        if [ -z "$individual_password" ]; then
                            cmd= "zip -r $destpath/$d.zip $d"
                        else
                            cmd= "zip -r -P '$individual_password' $destpath/$d.zip $d"
                        fi
                        screen -dmS zip_session bash -c "$cmd"
                    fi
                done
            fi

            popd > /dev/null

            blue " 已在新的 screen 会话 zip_session 中启动压缩任务 "
            ;;

        0)
            # 返回应用程序菜单
            app_menu
            ;;

        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            unzip_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    unzip_management
}
## ca-certificates
function ca_certificates_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============ca-certificates菜单=============== "
    green " 1. 安装 ca-certificates "
    black " 2. 卸载 ca-certificates "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue " 检测到您的系统为: $OS "

    case "$menuNumberInput" in
        1)
            if command -v update-ca-certificates &> /dev/null; then
                purple " 您已经安装过 ca-certificates "
                red " 两秒后自动返回 "
                sleep 2
                ca_certificates_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt update
                    sudo apt install -y ca-certificates
                    ;;
                centos|redhat)
                    sudo yum install -y ca-certificates
                    ;;
                arch)
                    sudo pacman -S ca-certificates
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    ca_certificates_management
                    return
                    ;;
            esac
            blue " ca-certificates 安装完成 "
            ;;
        2)
            if ! command -v update-ca-certificates &> /dev/null; then
                blue " 您没有安装 ca-certificates "
                red " 两秒后自动返回 "
                sleep 2
                ca_certificates_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    sudo apt remove -y ca-certificates
                    ;;
                centos|redhat)
                    sudo yum remove -y ca-certificates
                    ;;
                arch)
                    sudo pacman -R ca-certificates
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    ca_certificates_management
                    return
                    ;;
            esac
            black " ca-certificates 卸载完成 "
            ;;
        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            ca_certificates_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    ca_certificates_management
}
## SpeedTest CLI
function speedtest_cli_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============Speedtest CLI菜单=============== "
    green " 1. 安装 Speedtest CLI "
    green " 2. 运行 Speedtest CLI "
    green " 3. 指定节点运行 Speedtest CLI "
    black " 4. 卸载 Speedtest CLI "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue " 检测到您的系统为: $OS "

    case "$menuNumberInput" in
        1)
            if command -v speedtest &> /dev/null; then
                purple " 您已经安装过 Speedtest CLI "
                red " 两秒后自动返回 "
                sleep 2
                speedtest_cli_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    # Ubuntu/Debian 安装指令
                    blue " 将为您执行 Ubuntu/Debian 下的 Speedtest CLI 安装 "
                    sudo apt-get install curl
                    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
                    sudo apt-get install speedtest
                    ;;
                fedora|centos|redhat)
                    # Fedora/CentOS/RedHat 安装指令
                    blue " 将为您执行 Fedora/CentOS/RedHat 下的 Speedtest CLI 安装 "
                    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
                    sudo yum install speedtest
                    ;;
                Darwin) # macOS
                    # macOS 安装指令
                    blue " 将为您执行 MacOS 下的 Speedtest CLI 安装 "
                    brew tap teamookla/speedtest
                    brew update
                    brew install speedtest --force
                    ;;
                *)
                    red " 不支持的操作系统 "
                    return 1
                    ;;
            esac
            blue " Speedtest CLI 安装完成 "
            ;;

        2)
            if ! command -v speedtest &> /dev/null; then
                red " 您尚未安装 Speedtest CLI "
                red " 两秒后自动返回 "
                sleep 2
                speedtest_cli_management
                return
            fi
            # 运行 Speedtest
            speedtest
            ;;

        3)
            if ! command -v speedtest &> /dev/null; then
                red " 您尚未安装 Speedtest CLI "
                red " 两秒后自动返回 "
                sleep 2
                speedtest_cli_management
                return
            fi
            # 指定ID运行 Speedtest
            read -p " 请输入您想要指定的Speedtest服务器ID: " server_id
            speedtest --server-id=$server_id
            ;;

        4)
            if ! command -v speedtest &> /dev/null; then
                red " 您尚未安装 Speedtest CLI "
                red " 两秒后自动返回 "
                sleep 2
                speedtest_cli_management
                return
            fi
            # 卸载 Speedtest CLI
            case $OS in
                ubuntu|debian)
                    sudo apt-get remove --purge speedtest
                    ;;
                fedora|centos|redhat)
                    sudo yum remove speedtest
                    ;;
                Darwin) # macOS
                    brew uninstall speedtest
                    ;;
                *)
                    red " 不支持的操作系统 "
                    return 1
                    ;;
            esac
            black " Speedtest CLI 卸载完成 "
            ;;

        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            speedtest_cli_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    speedtest_cli_management
}
## Caddy
function caddy_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============Caddy菜单=============== "
    green " 1. 安装 Caddy "
    green " 2. Caddy 重新加载 "
    green " 3. 查看 Caddy 运行状态 "
    green " 4. 启动 Caddy "
    green " 5. 停止 Caddy "
    green " 6. 重启 Caddy "
    green " 7. 设置 Caddy 开机启动 "
    green " 8. 关闭 Caddy 开机启动 "
    black " 9. 卸载 Caddy "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue " 检测到您的系统为: $OS "

    case "$menuNumberInput" in
        1)
            caddy_management
            ;;
        2)
            blue " 重新加载 Caddy "
            sudo systemctl reload caddy
            ;;
        3)
            blue " 查看 Caddy 运行状态 "
            sudo systemctl status caddy
            ;;
        4)
            blue " 启动 Caddy "
            sudo systemctl start caddy
            ;;
        5)
            blue " 停止 Caddy "
            sudo systemctl stop caddy
            ;;
        6)
            blue " 重启 Caddy "
            sudo systemctl restart caddy
            ;;
        7)
            blue " 设置 Caddy 开机启动 "
            sudo systemctl enable caddy
            ;;
        8)
            blue " 关闭 Caddy 开机启动 "
            sudo systemctl disable caddy
            ;;
        9)
            if ! command -v caddy &> /dev/null; then
                blue " 您没有安装 Caddy "
                red " 两秒后自动返回 "
                sleep 2
                caddy_management
                return
            fi
            sudo apt remove -y caddy || sudo yum remove -y caddy || sudo pacman -R caddy
            black " Caddy 卸载完成 "
            ;;
        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            caddy_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    caddy_management
}

## aapanel
function aapanel_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============aapanel菜单=============== "
    green " 1. 安装 aapanel "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo 
        red " 无法检测您的操作系统类型 "
        return 1
    fi

    blue " 检测到您的系统为: $OS "

    case "$menuNumberInput" in
        1)
            case $OS in
                centos)
                    # CentOS 安装指令
                    blue " 将为您执行 CentOS 下的 aapanel 安装 "
                    sudo yum install -y wget
                    wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh
                    bash install.sh aapanel
                    ;;
                ubuntu|deepin)
                    # Ubuntu/Deepin 安装指令
                    blue " 将为您执行 Ubuntu/Deepin 下的 aapanel 安装 "
                    wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh
                    sudo bash install.sh aapanel
                    ;;
                debian)
                    # Debian 安装指令
                    blue " 将为您执行 Debian 下的 aapanel 安装 "
                    wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh
                    bash install.sh aapanel
                    ;;
                *)
                    red " 不支持的操作系统 "
                    return 1
                    ;;
            esac
            blue " aapanel 安装完成 "
            blue " 使用 bt 命令查看 aapanel 菜单"
            ;;
        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            aapanel_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    aapanel_management
}

# 科学上网
## soga
function soga_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============soga菜单=============== "
    green " 1. 安装 soga "
    green " 2. 运行 soga "
    yellow " =================================== "
    green " 0. 返回科学上网菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case "$menuNumberInput" in
        1)
            blue " 开始安装 soga "
            bash <(curl -Ls https://github.com/sprov065/soga/raw/master/soga.sh)
            blue " soga 安装完成 "
            ;;
        2)
            blue " 开始运行 soga "
            soga
            blue " soga 运行完成 "
            ;;
        0)
            vpn_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            soga_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    soga_management
}
## XrayR
function XrayR_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============XrayR菜单=============== "
    green " 1. 安装 XrayR "
    green " 2. 运行 XrayR "
    yellow " =================================== "
    green " 0. 返回科学上网菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case "$menuNumberInput" in
        1)
            blue " 开始安装 XrayR "
            bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)
            blue " XrayR 安装完成 "
            ;;
        2)
            blue "开始运行 XrayR "
            xrayr
            blue " XrayR 运行完成 "
            ;;
        0)
            vpn_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            XrayR_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    XrayR_management
}
## ss-go
function ss_go_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============ss-go菜单=============== "
    green " 1. 安装 ss-go "
    yellow " =================================== "
    green " 0. 返回科学上网菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case "$menuNumberInput" in
        1)
            blue " 开始安装 ss-go "
            wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ss-go.sh
            chmod +x ss-go.sh
            bash ss-go.sh
            blue " ss-go 安装完成 "
            ;;
        0)
            vpn_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            ss_go_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    ss_go_management
}
## 极光面板
function aurora_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============极光面板菜单============ "
    green " 1. 安装极光面板 "
    yellow " =================================== "
    green " 0. 返回科学上网菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case "$menuNumberInput" in
        1)
            blue " 开始安装极光面板 "
            bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
            blue " 极光面板安装完成 "
            ;;
        0)
            vpn_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            aurora_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    aurora_management
}

# 菜单

# 系统菜单
system_menu() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " =========ToolBox系统菜单============ "
    green " 1.BBR加速 "
    green " 2.设置时区 "
    green " 3.设置swap "
    green " 4.IPv4/IPv6优先级调整 "

    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回主菜单"
    echo
    read -p " 请输入数字: " menuNumberInput
    case "$menuNumberInput" in
        1 )
            bbr_management
	;;
        2 )
            swap_management
	;;
        3 )
            swap_management
	;;
        4 )
            network_management
    ;;
        0 )
            start_menu
    ;;
        * )
            clear
            red " 请输入正确数字  "
            red " 两秒后自动返回 "
            sleep 2s
            system_menu
        ;;
    esac
}
# 软件菜单
app_menu() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " =========ToolBox软件菜单========== "
    green " 1. wget, curl 和 git "
    green " 2. nano "
    green " 3. screen "
    green " 4. unzip "
    green " 5. ca-certificates "
    green " 6. SpeedTest CLI "
    green " 7. Caddy "
    green " 8. aapanel "


    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================== "
    green " 0. 返回主菜单"
    echo
    read -p " 请输入数字: " menuNumberInput
    case "$menuNumberInput" in
        1 )
            install_wget_curl_git
	;;
        2 )
            nano_management
	;;
        3 )
            screen_management
	;;
        4 )
            unzip_management
    ;;
        5 )
            ca_certificates_management
    ;;
        6 )
            speedtest_cli_management
    ;;
        7 )
            caddy_management
    ;;
        8 )
            aapanel_management
    ;;
        0 )
            start_menu
    ;;
        * )
            clear
            red " 请输入正确数字  "
            red " 两秒后自动返回 "
            sleep 2s
            app_menu
        ;;
    esac
}
# 科学上网菜单
vpn_menu() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " =========ToolBox科学上网菜单======== "
    green " 1.安装soga "
    green " 2.安装XrayR "
    green " 3.安装ss-go "
    green " 4.安装极光面板 "


    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回主菜单"
    echo
    read -p " 请输入数字: " menuNumberInput
    case "$menuNumberInput" in
        1 )
            soga_management
	;;
        2 )
            XrayR_management
	;;
        3 )
            ss_go_management
	;;
        4 )
            aurora_management
    ;;
        0 )
            start_menu
    ;;
        * )
            clear
            red " 请输入正确数字  "
            red " 两秒后自动返回 "
            sleep 2s
            vpn_menu
        ;;
    esac
}
# 主菜单
start_menu() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " ==========ToolBox主菜单============ "
	orange " 1.系统菜单 "
    orange " 2.软件菜单 "
    orange " 3.科学上网菜单 "
    echo


    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 退出脚本"
    echo
    read -p " 请输入数字: " menuNumberInput
    case "$menuNumberInput" in
        1 )
            system_menu
	;;
        2 )
            app_menu
	;;
        3 )
            vpn_menu
    ;;
        0 )
            exit 1
    ;;
        * )
            clear
            red " 请输入正确数字  "
            red " 两秒后自动返回主菜单"
            sleep 2s
            start_menu
        ;;
    esac
}

start_menu

