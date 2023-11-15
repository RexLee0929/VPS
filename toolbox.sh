#by Rex Lee


##脚本所用到的颜色
## 报错相关用红色
red="\033[31m\033[01m$1\033[0m"
## 常规用绿色
green=""\033[32m\033[01m$1\033[0m"
## 标题用黄色
yellow="\033[33m\033[01m$1\033[0m"
## 提示用蓝色
blue="\033[34m\033[01m$1\033[0m"
## 重要提示用橙色
orange="\033[38;5;208m\033[01m$1\033[0m"
## 重复操作用紫色
purple="\033[38;5;5m$1\033[0m"
## 卸载相关用黑色
black="\033[38;5;0m$1\033[0m"


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
    if ! wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"; then
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
function Timezone_management(){
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
            Timezone_management
        ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    Timezone_management
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
## 配置IPv6
function ipv6_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " =============工具菜单=============== "
    green " 1. 添加 IPv6 配置 "
    green " 2. 删除 IPv6 配置 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case $menuNumberInput in

        1)
            red " 暂时搁置,以后再更新 "
            ;;
        2)
            red " 暂时搁置,以后再更新 "
            ;;
        0)
            # 返回系统菜单
            system_menu
            ;;
        *)
            red " 无效的选择,请重新输入 "
            red " 两秒后自动返回 "
            sleep 2s
            ipv6_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    ipv6_management
}
## 融合怪ECS
function ecs_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    blue " ECS作者: https://github.com/spiritLHLS "
    yellow " ==============ECS菜单=============== "
    green " 1. 直接运行融合怪ECS "
    green " 2. screen 运行融合怪ECS "
    green " 3. 查看历史评测结果 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case $menuNumberInput in

        1)
            # 直接运行融合怪ECS
            curl -L https://github.com/spiritLHLS/ecs/raw/main/ecs.sh -o ecs.sh
            chmod +x ecs.sh
            bash ecs.sh
            ;;
        2)
            # 使用screen运行融合怪ECS
            curl -L https://github.com/spiritLHLS/ecs/raw/main/ecs.sh -o ecs.sh
            chmod +x ecs.sh
            screen -S ecs_session bash ecs.sh
            green " 已在 screen 会话 'ecs_session' 中运行融合怪 ECS "
            blue " 要重新进入该会话，请执行: screen -r ecs_session"
            ;;
        3)
            # 查看历史评测结果（这里你可以添加你自己的代码）
            ;;
        0)
            # 返回系统菜单
            system_menu
            ;;
        *)
            red " 无效的选择,请重新输入 "
            red " 两秒后自动返回 "
            sleep 2s
            ecs_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    ecs_management
}
## 魔方换源
function source_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " =============换源菜单=============== "
    green " 1. 魔方 Debian 换源 "
    echo
    orange " 如有其他换源需求,请提issue "
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case $menuNumberInput in

        1)
            # 魔方Debian换源
            sed -i 's/bullseye\/updates/bullseye-security/g' /etc/apt/sources.list
            green " 已成功更改魔方 Debian 源 "
            blue " 请运行 'sudo apt update' 以更新软件包信息 "
            ;;
        0)
            # 返回系统菜单
            system_menu
            ;;
        *)
            red " 无效的选择,请重新输入 "
            red " 两秒后自动返回 "
            sleep 2s
            source_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    source_management
}
## 流媒体检测
function mediacheck_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============流媒体检测菜单============= "
    green " 1. 执行流媒体检测 "
    green " 2. 执行 IPv4 流媒体检测 "
    green " 3. 执行 IPv6 流媒体检测 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case $menuNumberInput in
        1)
            # 执行流媒体检测
            bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh)
            green " 流媒体检测完成 "
            ;;
        2)
            # 执行 IPv4 流媒体检测
            bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -M 4
            green " IPv4 流媒体检测完成 "
            ;;
        3)
            # 执行 IPv6 流媒体检测
            bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -M 6
            green " IPv6 流媒体检测完成 "
            ;;
        0)
            # 返回应用程序菜单
            system_menu
            ;;
        *)
            red " 无效的选择,请重新输入 "
            red " 两秒后自动返回 "
            sleep 2s
            mediacheck_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    mediacheck_management
}
## 游戏延迟检测
function gamecheck_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============游戏延迟检测菜单=========== "
    green " 1. 执行游戏延迟检测 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case $menuNumberInput in
        1)
            # 执行游戏延迟检测
            bash <(curl -L -s https://raw.githubusercontent.com/lmc999/GamePing/main/GamePing.sh)
            green " 游戏延迟检测完成 "
            ;;
        0)
            # 返回应用程序菜单
            system_menu
            ;;
        *)
            red " 无效的选择,请重新输入 "
            red " 两秒后自动返回 "
            sleep 2s
            gamecheck_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    gamecheck_management
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
    black " 8. 卸载 unzip "
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

    8)
        if ! command -v unzip &> /dev/null && ! command -v zip &> /dev/null; then
            red " 您没有安装 unzip 或 zip "
            red " 两秒后自动返回 "
            sleep 2
            unzip_management
            return
        fi

        case $OS in
            ubuntu|debian)
                blue " 将为您执行 $OS 下的 unzip 卸载 "
                sudo apt remove -y unzip
                ;;
            centos|redhat)
                blue " 将为您执行 $OS 下的 unzip 卸载 "
                sudo yum remove -y unzip
                ;;
            arch)
                blue " 将为您执行 $OS 下的 unzip 卸载 "
                sudo pacman -R unzip
                ;;
            *)
                red " 不支持的操作系统 "
                red " 两秒后自动返回 "
                sleep 2
                unzip_management
                return
                ;;
        esac
        black " unzip 卸载完成 "
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
    green " 2. 查看 Caddy 配置文件 "
    green " 3. 添加 Caddy 配置 "
    green " 4. 删除 Caddy 配置 "
    green " 5. Caddy 重新加载 "
    green " 6. 查看 Caddy 运行状态 "
    green " 7. 启动 Caddy "
    green " 8. 停止 Caddy "
    green " 9. 重启 Caddy "
    green " 10. 设置 Caddy 开机启动 "
    green " 11. 关闭 Caddy 开机启动 "
    black " 12. 卸载 Caddy "
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
            if command -v caddy &> /dev/null; then
                purple " 您已经安装过 Caddy "
                red " 两秒后自动返回 "
                sleep 2
                caddy_management
                return
            fi
            case $OS in
                ubuntu|debian|raspbian)
                    blue " 将为您执行 Debian, Ubuntu, Raspbian 下的 Caddy 安装 "
                    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
                    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
                    sudo apt update
                    sudo apt install caddy
                    ;;
                fedora)
                    blue " 将为您执行 Fedora 下的 Caddy 安装 "
                    sudo dnf install 'dnf-command(copr)'
                    sudo dnf copr enable @caddy/caddy
                    sudo dnf install caddy
                    ;;
                centos|redhat)
                    if [[ $VERSION_ID == 8* ]]; then
                        blue " 将为您执行 RHEL/CentOS 8 下的 Caddy 安装 "
                        sudo dnf install 'dnf-command(copr)'
                        sudo dnf copr enable @caddy/caddy
                        sudo dnf install caddy
                    elif [[ $VERSION_ID == 7* ]]; then
                        blue " 将为您执行 RHEL/CentOS 7 下的 Caddy 安装 "
                        sudo yum install yum-plugin-copr
                        sudo yum copr enable @caddy/caddy
                        sudo yum install caddy
                    fi
                    ;;
            esac
            ;;
        2)
            display_caddy_config
            ;;
        3)
            clear
            # 显示配置列表
            display_caddy_config

            blue " 添加配置 "
            # 提示用户输入站点
            read -p " 请输入站点 (例如: nmsl.baidu.com): " siteName
            # 提示用户输入监听地址，并为其设置一个默认值
            read -p " 请输入监听地址 (默认: localhost): " listenAddress
            listenAddress=${listenAddress:-localhost}
            # 提示用户输入监听端口
            read -p " 请输入监听端口 (例如: 7800): " listenPort
            # 提示用户选择是否启用tls
            read -p " 是否启用 TLS (y/n): " enableTls

            # 根据用户的输入构建配置段
            if [[ "$enableTls" == "y" || "$enableTls" == "Y" ]]; then
                configToAdd=$(echo -e "\n$siteName {\n    reverse_proxy $listenAddress:$listenPort\n    tls {\n        on_demand\n    }\n}")
            else
                configToAdd=$(echo -e "\n$siteName {\n    reverse_proxy $listenAddress:$listenPort\n}")
            fi

            # 将构建的配置段追加到配置文件的末尾
            echo "$configToAdd" >> /etc/caddy/Caddyfile

            # 输出提示信息
            green " 配置添加完成,请重新运行 caddy 使配置生效 "
            ;;

        4)
            clear
            # 显示配置列表
            display_caddy_config

            # 提示用户输入要删除的配置的序号
            read -p " 请输入需要删除的配置的序号: " deleteIndex

            # 检查输入的序号是否有效
            if [[ ! ${siteStartLines[$deleteIndex]} || ! ${siteEndLines[$deleteIndex]} ]]; then
                red " 输入的序号无效 "
                read -n 1 -s -r -p " 按任意键返回配置管理菜单... "
                caddy_management
            fi

            # 确认删除
            read -p " 请确认是否删除配置 (y/n，默认为n): " confirmDelete
            if [[ "$confirmDelete" == "y" || "$confirmDelete" == "Y" ]]; then
                # 获取要删除的配置段的开始和结束行号
                local startLine=${siteStartLines[$deleteIndex]}
                local endLine=${siteEndLines[$deleteIndex]}
                
                # 使用sed删除指定行
                awk -v start="$startLine" -v end="$endLine" 'NR < start || NR > end + 1' /etc/caddy/Caddyfile > /tmp/Caddyfile.tmp && mv /tmp/Caddyfile.tmp /etc/caddy/Caddyfile

                green " 配置已删除 "
            else
                red " 操作已取消 "
            fi

            ;;
        5)
            blue " 重新加载 Caddy "
            sudo systemctl reload caddy
            ;;
        6)
            blue " 查看 Caddy 运行状态 "
            sudo systemctl status caddy
            ;;
        7)
            blue " 启动 Caddy "
            sudo systemctl start caddy
            ;;
        8)
            blue " 停止 Caddy "
            sudo systemctl stop caddy
            ;;
        9)
            blue " 重启 Caddy "
            sudo systemctl restart caddy
            ;;
        10)
            blue " 设置 Caddy 开机启动 "
            sudo systemctl enable caddy
            ;;
        11)
            blue " 关闭 Caddy 开机启动 "
            sudo systemctl disable caddy
            ;;
        12)
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
## Caddy 配置显示
function display_caddy_config() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ==========Caddy当前配置============= "

    # 表头
    local header="┌────────┬──────────────────────────┬──────────────┬──────────┬────────┐"
    local title="│  序号  │           站点           │   监听地址   │ 监听端口 │  TLS   │"
    local divider="├────────┼──────────────────────────┼──────────────┼──────────┼────────┤"
    local footer="└────────┴──────────────────────────┴──────────────┴──────────┴────────┘"

    echo "$header"
    echo "$title"
    echo "$divider"

    # 使用awk解析并格式化输出
    awk -v divider="$divider" -v footer="$footer" '
        BEGIN {
            count = 0; stackIdx = 0; lastLine = 0;
            delete siteStartLines;
            delete siteEndLines;
        }
        
        /^[^ ]+ {/ {  # When we see a site start
            if (lastLine) {
                print divider;
            }
            count++;
            site = $1;
            siteStartLines[count] = NR;
            stack[stackIdx++] = count;
            getline;
            split($2, array, ":");
            listen_address = array[1];
            listen_port = array[2];
            if (listen_address == "" || listen_port == "") {
                listen_address = "unknown";
                listen_port = "unknown";
            }
            getline; 
            if ($1 == "tls") { tls = "已启用" } else { tls = "未启用" }
            printf "│ %-6s │ %-24s │ %-12s │ %-8s │ %-6s │\n", count, site, listen_address, listen_port, tls;
            lastLine = 1;
        }

        /}/ {  # When we see a closing brace
            siteEndLines[stack[--stackIdx]] = NR;
        }

        END {
            print footer;
            for (i in siteStartLines) {
                printf "siteStartLines[%d]=%d; siteEndLines[%d]=%d\n", i, siteStartLines[i], i, siteEndLines[i] > "/dev/stderr";
            }
        }
    ' /etc/caddy/Caddyfile 2> /tmp/lineNumbers.tmp

    # 从临时文件中读取行号并保存到关联数组中
    while IFS="=;" read -r key value; do
        eval "$key=$value"
    done < /tmp/lineNumbers.tmp

    # 删除临时文件
    rm -f /tmp/lineNumbers.tmp
}
declare -A siteStartLines siteEndLines  # 声明两个关联数组来保存站点的开始和结束行号
## aapanel
function aapanel_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ===========aapanel菜单============== "
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
## Nezha Agent
function nezha_agent_management() {
    clear
    blue " Rex Lee's ToolBox "
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ===========哪吒监控菜单============= "
    green " 1. 安装 NeZha 监控 "
    green " 2. 管理 NeZha 菜单 "
    green " 3. 查看 Nezha Agent "
    green " 4. 创建 Nezha Agent "
    green " 5. 启动 Nezha Agent "
    green " 6. 停止 Nezha Agent "
    green " 7. 重启 Nezha Agent "
    green " 8. 设置 Nezha Agent 开机启动 "
    green " 9. 关闭 Nezha Agent 开机启动 "
    green " 10. 删除 Nezha Agent 配置 "

    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case "$menuNumberInput" in
        1)
            read -p " 是否使用中国镜像？(y/n，默认为n): " useCNMirror
            if [[ "$useCNMirror" == "y" || "$useCNMirror" == "Y" ]]; then
                curl -L https://cdn.jsdelivr.net/gh/naiba/nezha@master/script/install.sh -o nezha.sh
                chmod +x nezha.sh
                sudo CN=true ./nezha.sh
            else
                curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -o nezha.sh
                chmod +x nezha.sh
                sudo ./nezha.sh
            fi
            ;;
        2)
            clear
            ./nezha.sh
            ;;
        3)
            clear
            display_nezha_config
            ;;
        4)
            clear
            display_nezha_config
            echo " 创建 Nezha Agent 服务配置 "
            
            # 询问用户输入新的配置名称、Panel IP、端口和密钥
            read -p " 请输入新的配置名称: " config_name
            read -p " 请输入Panel IP: " panel_ip
            read -p " 请输入端口: " port
            read -p " 请输入密钥: " key

            # 创建服务文件路径
            local service_file_path="/etc/systemd/system/nezha-agent_${config_name}.service"

            # 创建服务文件内容
            local service_content="[Unit]\nDescription=Nezha Agent ${config_name}\nAfter=syslog.target\n\n[Service]\nType=simple\nUser=root\nGroup=root\nWorkingDirectory=/opt/nezha/agent/\nExecStart=/opt/nezha/agent/nezha-agent -s ${panel_ip}:${port} -p ${key}\nRestart=always\n\n[Install]\nWantedBy=multi-user.target"

            # 将服务内容写入文件
            echo -e "$service_content" > "$service_file_path"

            echo " 服务配置文件已创建: $service_file_path "
            echo " 请使用 systemctl 命令启动和管理服务 "
            ;;
        5)
            clear
            display_nezha_config
            read -p " 请输入要启动的 Nezha Agent 序号 (输入0返回): " index
            if [ "$index" -eq 0 ]; then
                nezha_agent_management
            elif [ -z "${services[$index]}" ]; then
                red " 无效的序号，返回菜单 "
                sleep 2
                nezha_agent_management
            else
                local serviceName=${services[$index]}
                systemctl start "$serviceName"
                echo " Nezha Agent ${index} 已启动 "
            fi
            ;;

        6)
            clear
            display_nezha_config
            read -p " 请输入要停止的 Nezha Agent 序号 (输入0返回):  " index
            if [ "$index" -eq 0 ]; then
                nezha_agent_management
            elif [ -z "${services[$index]}" ]; then
                red " 无效的序号，返回菜单 "
                sleep 2
                nezha_agent_management
            else
                local serviceName=${services[$index]}
                systemctl stop "$serviceName"
                echo " Nezha Agent ${index} 已停止 "
            fi
            ;;

        7)
            clear
            display_nezha_config
            read -p " 请输入要重启的 Nezha Agent 序号 (输入0返回): " index
            if [ "$index" -eq 0 ]; then
                nezha_agent_management
            elif [ -z "${services[$index]}" ]; then
                red " 无效的序号，返回菜单 "
                sleep 2
                nezha_agent_management
            else
                local serviceName=${services[$index]}
                systemctl restart "$serviceName"
                echo " Nezha Agent ${index} 已重启 "
            fi
            ;;

        8)
            clear
            display_nezha_config
            read -p " 请输入要设置开机启动的 Nezha Agent 序号 (输入0返回):  " index
            if [ "$index" -eq 0 ]; then
                nezha_agent_management
            elif [ -z "${services[$index]}" ]; then
                red " 无效的序号，返回菜单 "
                sleep 2
                nezha_agent_management
            else
                local serviceName=${services[$index]}
                systemctl enable "$serviceName"
                echo " Nezha Agent ${index} 已设置开机启动 "
            fi
            ;;

        9)
            clear
            display_nezha_config
            read -p " 请输入要关闭开机启动的 Nezha Agent 序号 (输入0返回):  " index
            if [ "$index" -eq 0 ]; then
                nezha_agent_management
            elif [ -z "${services[$index]}" ]; then
                red " 无效的序号，返回菜单 "
                sleep 2
                nezha_agent_management
            else
                local serviceName=${services[$index]}
                systemctl disable "$serviceName"
                echo " Nezha Agent ${index} 已关闭开机启动 "
            fi
            ;;
        10)
            clear
            display_nezha_config
            read -p " 请输入要删除的 Nezha Agent 序号:  " index
            local serviceName=${services[$index]}
            systemctl stop "$serviceName"
            systemctl disable "$serviceName"
            rm -f "/etc/systemd/system/${serviceName}.service"
            echo " Nezha Agent ${index} 已删除 "
            ;;
        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            nezha_agent_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    nezha_agent_management
}
declare -A services
## NeZha 配置显示
function display_nezha_config() {
    clear
    blue " Rex Lee's ToolBox "
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ==========NeZha当前配置============= "

    # 表头
    local header="┌──────┬────────────┬─────────────────────┬─────────┬──────────────────────┬──────────┬────────────┐"
    local title="│ 序号 │    名称    │       Panel IP      │   Port  │         Key          │   状态   │  开机启动  │"
    local divider="├──────┼────────────┼─────────────────────┼─────────┼──────────────────────┼──────────┼────────────┤"
    local footer="└──────┴────────────┴─────────────────────┴─────────┴──────────────────────┴──────────┴────────────┘"

    echo "$header"
    echo "$title"

    # 计数器
    local count=1

    # 查找并解析配置文件
    for file in /etc/systemd/system/nezha-agent.service /etc/systemd/system/nezha-agent_*.service; do
        if [ -f "$file" ]; then
            echo "$divider" # 添加分隔线

            local name="NeZha"
            if [[ "$file" =~ nezha-agent_(.*)\.service ]]; then
                name=${BASH_REMATCH[1]}
            fi
            local serviceName=$(basename $file .service)
            services[$count]=$serviceName
            local execLine=$(grep 'ExecStart=' $file)
            local panelIP=$(echo $execLine | sed -n 's/.*-s \([^:]*\):.*/\1/p')
            local port=$(echo $execLine | sed -n 's/.*:\([^ ]*\) -p.*/\1/p')
            local secretKey=$(echo $execLine | sed -n 's/.*-p \(.*\)/\1/p')
            local status=$(systemctl is-active $serviceName)
            local enableStatus=$(systemctl is-enabled $serviceName)
            printf "│ %-4s │ %-10s │ %-19s │ %-7s │ %-20s │ %-8s │ %-10s │\n" $count $name $panelIP $port $secretKey $status $enableStatus

            count=$((count+1))
        fi
    done

    echo "$footer"
}
## Aria2
function aria2_management() {
    clear
    blue " Rex Lee's ToolBox "
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ==============Aria2================ "
    green " 1. 运行 Aria2 安装脚本 "
    green " 2. Aria2 菜单 "
    green " 3. Aria2 修复无法开机启动 "
    green " 4. 查看 Aria2 运行状态 "
    green " 5. 启动 Aria2 "
    green " 6. 停止 Aria2 "
    green " 7. 重启 Aria2 "
    green " 8. 设置 Aria2 开机启动 "
    green " 9. 关闭 Aria2 开机启动 "

    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回应用程序菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case $menuNumberInput in

        1)
            # 运行 Aria2 安装脚本
            apt-get install -y wget curl ca-certificates
            wget -N git.io/aria2.sh
            chmod +x aria2.sh
            ./aria2.sh
            ;;
        2)
            ./aria2.sh
            ;;
        3)
            # 检查 /etc/systemd/system/aria2.service 是否存在
            if [[ -f /etc/systemd/system/aria2.service ]]; then
                # 读取现有配置
                current_config=$(cat /etc/systemd/system/aria2.service)
                
                # 准备目标配置
                target_config=$(printf "[Unit]\nDescription=Aria2\nAfter=network.target\n[Service]\nUser=root\nLimitNOFILE=51200\nExecStart=/usr/local/bin/aria2c --conf-path=/root/.aria2c/aria2.conf\nRestart=on-failure\n[Install]\nWantedBy=multi-user.target\n")

                # 判断当前配置是否与目标配置一致
                if [[ "$current_config" != "$target_config" ]]; then
                    printf "%s" "$target_config" > /etc/systemd/system/aria2.service
                    green " Aria2 服务配置已更新 "
                else
                    green " Aria2 服务配置已经是目标配置，无需更改 "
                fi
            else
                # 如果服务文件不存在，则创建
                printf "%s" "$target_config" > /etc/systemd/system/aria2.service
                green " Aria2 服务已创建 "
            fi
            
            # 检查并删除冲突的 /etc/init.d/aria2 文件
            if [[ -f /etc/init.d/aria2 ]]; then
                rm -f /etc/init.d/aria2
                green " 为避免冲突，/etc/init.d/aria2 文件已删除 "
            fi
            ;;
        4)
            # 查看 Aria2 运行状态
            systemctl status aria2
            ;;
        5)
            # 启动 Aria2
            systemctl start aria2
            blue " Aria2 已启动 "
            ;;
        6)
            # 停止 Aria2
            systemctl stop aria2
            blue " Aria2 已停止 "
            ;;
        7)
            # 重启 Aria2
            systemctl restart aria2
            blue " Aria2 已重启 "
            ;;
        8)
            # 设置 Aria2 开机启动
            systemctl enable aria2
            blue " Aria2 已设置为开机启动 "
            ;;
        9)
            # 关闭 Aria2 开机启动
            systemctl disable aria2
            blue " Aria2 的开机启动已关闭 "
            ;;
        0)
            # 返回系统菜单
            system_menu
            ;;
        *)
            red " 无效的选择,请重新输入 "
            red " 两秒后自动返回 "
            sleep 2s
            aria2_management
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    aria2_management
}
## 7zip
function 7zip_management() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " =============7zip菜单============== "
    green " 1. 安装 7zip "
    green " 2. 使用 7zip 解压文件 "
    green " 3. 使用 7zip 压缩文件夹 "
    green " 4. 批量使用 7zip 解压文件 "
    green " 5. 批量使用 7zip 压缩文件夹 "
    green " 6. 使用 screen 执行 7zip 批量解压 "
    green " 7. 使用 screen 执行 7zip 批量压缩 "
    black " 8. 卸载 7z "
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
            if command -v 7z &> /dev/null; then
                purple " 您已经安装过 7zip 了 "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    blue " 将为您执行 $OS 下的 7zip 安装 "
                    apt update
                    apt install -y p7zip p7zip-full p7zip-rar
                    ;;
                centos|redhat)
                    blue " 将为您执行 $OS 下的 7zip 安装 "
                    sudo yum install -y p7zip p7zip-plugins
                    ;;
                arch)
                    blue " 将为您执行 $OS 下的 7zip 安装 "
                    sudo pacman -S p7zip
                    ;;

                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    7zip_management
                    return
                    ;;
            esac
            blue " 7zip 及其所有组件安装完成 "
            ;;
        2)
            if ! command -v 7z &> /dev/null; then
                red " 您没有安装 7zip "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
                return
            fi
            read -p " 请输入您要解压的文件路径: " archive_path
            read -p " 请输入解压到的路径: " dest_path
            mkdir -p "$dest_path"
            read -p " 请输入密码 (如果不想设置密码,请直接按 Enter ): " password
            if [ -z "$password" ]; then
                7z x "$archive_path" -o"$dest_path"
            else
                7z x "$archive_path" -o"$dest_path" -p"$password"
            fi
            ;;
        3)
            if ! command -v 7z &> /dev/null; then
                red " 您没有安装 7zip "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
                return
            fi
            read -p " 请输入您要压缩的文件夹路径: " folder_path
            read -p " 请输入压缩包的存放路径: " dest_path
            mkdir -p "$dest_path"
            read -p " 请输入密码 (如果不想设置密码,请直接按 Enter ): " password
            archive_name=$(basename "$folder_path").7z
            if [ -z "$password" ]; then
                7z a "$dest_path/$archive_name" "$folder_path"
            else
                7z a -p"$password" "$dest_path/$archive_name" "$folder_path"
            fi
            ;;
        4)
            if ! command -v 7z &> /dev/null; then
                red " 您没有安装 7zip "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
                return
            fi
            read -p " 请输入包含压缩文件的目录路径: " dir_path
            read -p " 请输入解压到的目标路径: " target_path
            mkdir -p "$target_path"
            read -p " 所有文件是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                for archive in "$dir_path"/*.7z; do
                    if [ -z "$unified_password" ]; then
                        7z x "$archive" -o"$target_path"
                    else
                        7z x "$archive" -o"$target_path" -p"$unified_password"
                    fi
                done
            else
                for archive in "$dir_path"/*.7z; do
                    read -p " 为 $archive 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                    if [ -z "$individual_password" ]; then
                        7z x "$archive" -o"$target_path"
                    else
                        7z x "$archive" -o"$target_path" -p"$individual_password"
                    fi
                done
            fi
            ;;
        5)
            if ! command -v 7z &> /dev/null; then
                red " 您没有安装 7zip "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
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
                        archive_name=$(basename "$dir").7z
                        if [ -z "$unified_password" ]; then
                            7z a "$destpath/$archive_name" "$dir"
                        else
                            7z a -p"$unified_password" "$destpath/$archive_name" "$dir"
                        fi
                    fi
                done
            else
                for dir in *; do
                    if [ -d "$dir" ]; then
                        read -p " 为 $dir 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                        archive_name=$(basename "$dir").7z
                        if [ -z "$individual_password" ]; then
                            7z a "$destpath/$archive_name" "$dir"
                        else
                            7z a -p"$individual_password" "$destpath/$archive_name" "$dir"
                        fi
                    fi
                done
            fi

            # 返回原始目录
            popd > /dev/null
            ;;
        6)
            # 批量解压在screen会话中
            if ! command -v 7z &> /dev/null || ! command -v screen &> /dev/null; then
                red " 您没有安装 7zip 或 screen "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
                return
            fi
            read -p " 请输入包含 7z 文件的目录路径: " dirpath
            read -p " 请输入要解压到的目标路径: " targetpath
            mkdir -p "$targetpath"
            read -p " 所有文件是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                cmd="for z in $dirpath/*.7z; do 7z x -o$targetpath -p'$unified_password' \$z; done"
                screen -dmS un7z_session bash -c "$cmd"
            else
                for z in "$dirpath"/*.7z; do
                    read -p " 为 $z 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                    cmd="7z x -o$targetpath -p'$individual_password' $z"
                    screen -dmS un7z_session bash -c "$cmd"
                done
            fi
            blue " 已在新的 screen 会话 un7z_session 中启动解压任务 "
            ;;

        7)
            # 批量压缩在screen会话中
            if ! command -v 7z &> /dev/null || ! command -v screen &> /dev/null; then
                red " 您没有安装 7zip 或 screen "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
                return
            fi
            read -p " 请输入包含文件夹的目录路径: " dirpath
            read -p " 请输入压缩包的存放路径: " destpath
            mkdir -p "$destpath"
            read -p " 所有文件夹是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            pushd "$dirpath" > /dev/null

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                cmd="for d in *; do if [ -d \$d ]; then 7z a -p'$unified_password' $destpath/\$d.7z \$d; fi; done"
                screen -dmS 7z_session bash -c "$cmd"
            else
                for d in *; do
                    if [ -d "$d" ]; then
                        read -p " 为 $d 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                        cmd="7z a -p'$individual_password' $destpath/$d.7z $d"
                        screen -dmS 7z_session bash -c "$cmd"
                    fi
                done
            fi
            popd > /dev/null

            blue " 已在新的 screen 会话 7z_session 中启动压缩任务 "
            ;;
        8)
            if ! command -v 7z &> /dev/null; then
                red " 您没有安装 7zip "
                red " 两秒后自动返回 "
                sleep 2
                7zip_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    blue " 将为您执行 $OS 下的 7zip 卸载 "
                    sudo apt remove -y p7zip p7zip-full p7zip-rar
                    ;;
                centos|redhat)
                    blue " 将为您执行 $OS 下的 7zip 卸载 "
                    sudo yum remove -y p7zip p7zip-plugins
                    ;;
                arch)
                    blue " 将为您执行 $OS 下的 7zip 卸载 "
                    sudo pacman -R p7zip
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    7zip_management
                    return
                    ;;
            esac
            black " 7zip 卸载完成 "
            ;;

        0)
            # 返回应用程序菜单
            app_menu
            ;;

        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            7zip_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    7zip_management
}
## rar
function rar_management() {
    clear
    blue " Rex Lee's ToolBox "
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============rar菜单================= "
    green " 1. 安装 rar "
    green " 2. 使用 rar 解压文件 "
    green " 3. 使用 rar 压缩文件夹 "
    green " 4. 批量使用 rar 解压文件 "
    green " 5. 批量使用 rar 压缩文件夹 "
    green " 6. 使用 screen 执行 rar 批量解压 "
    green " 7. 使用 screen 执行 rar 批量压缩 "
    black " 8. 卸载 rar "
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
            if command -v rar &> /dev/null && command -v unrar &> /dev/null; then
                purple " 您已经安装过 rar 和 unrar 了 "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    blue " 将为您执行 $OS 下的 rar 和 unrar 安装 "
                    sudo apt update
                    sudo apt install -y rar unrar
                    ;;
                centos|redhat)
                    blue " 将为您执行 $OS 下的 rar 和 unrar 手动安装 "
                    sudo wget https://www.rarlab.com/rar/rarlinux-x64-623.tar.gz --no-check-certificate
                    sudo tar zxvf rarlinux-x64-623.tar.gz -C /usr/local
                    sudo ln -s /usr/local/rar/rar /usr/local/bin/rar
                    sudo ln -s /usr/local/rar/unrar /usr/local/bin/unrar
                    ;;
                arch)
                    blue " 将为您执行 $OS 下的 rar 和 unrar 安装 "
                    sudo pacman -S rar unrar
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    rar_management
                    return
                    ;;
            esac
            blue " rar 和 unrar 安装完成 "
            ;;
        2)
            if ! command -v rar &> /dev/null; then
                red " 您没有安装 rar "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
                return
            fi
            read -p " 请输入您要解压的rar文件路径: " rarfile
            read -p " 请输入解压到的路径: " destpath
            mkdir -p "$destpath"
            read -p " 请输入密码 (如果不想设置密码,请直接按 Enter ): " password
            if [ -z "$password" ]; then
                rar x "$rarfile" "$destpath"
            else
                rar x -p"$password" "$rarfile" "$destpath"
            fi
            ;;
        3)
            if ! command -v rar &> /dev/null; then
                red " 您没有安装 rar "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
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
                rar a "$destpath/$foldername.rar" "$foldername"
            else
                rar a -p"$password" "$destpath/$foldername.rar" "$foldername"
            fi
            ;;
        4)
            if ! command -v rar &> /dev/null; then
                red " 您没有安装 rar "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
                return
            fi
            read -p " 请输入包含rar文件的目录路径: " dirpath
            read -p " 请输入要解压到的目标路径: " targetpath
            mkdir -p "$targetpath"
            read -p " 所有文件是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                for r in "$dirpath"/*.rar; do
                    if [ -z "$unified_password" ]; then
                        rar x "$r" "$targetpath"
                    else
                        rar x -p"$unified_password" "$r" "$targetpath"
                    fi
                done
            else
                for r in "$dirpath"/*.rar; do
                    read -p " 为 $r 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                    if [ -z "$individual_password" ]; then
                        rar x "$r" "$targetpath"
                    else
                        rar x -p"$individual_password" "$r" "$targetpath"
                    fi
                done
            fi
            ;;
        5)
            if ! command -v rar &> /dev/null; then
                red " 您没有安装 rar "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
                return
            fi

            read -p " 请输入包含文件夹的目录路径: " dirpath
            read -p " 请输入压缩包的存放路径: " destpath
            mkdir -p "$destpath"
            read -p " 所有文件夹是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            pushd "$dirpath" > /dev/null

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                for dir in *; do
                    if [ -d "$dir" ]; then
                        if [ -z "$unified_password" ]; then
                            rar a "$destpath/$dir.rar" "$dir"
                        else
                            rar a -p"$unified_password" "$destpath/$dir.rar" "$dir"
                        fi
                    fi
                done
            else
                for dir in *; do
                    if [ -d "$dir" ]; then
                        read -p " 为 $dir 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                        if [ -z "$individual_password" ]; then
                            rar a "$destpath/$dir.rar" "$dir"
                        else
                            rar a -p"$individual_password" "$destpath/$dir.rar" "$dir"
                        fi
                    fi
                done
            fi

            popd > /dev/null
            ;;
        6)
            # 批量解压在screen会话中
            if ! command -v rar &> /dev/null || ! command -v screen &> /dev/null; then
                red " 您没有安装 rar 或 screen "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
                return
            fi
            read -p " 请输入包含 rar 文件的目录路径: " dirpath
            read -p " 请输入要解压到的目标路径: " targetpath
            mkdir -p "$targetpath"
            read -p " 所有文件是否使用相同的密码? (直接按 Enter 表示'是',其他表示'否') " same_password

            if [ -z "$same_password" ]; then
                read -p " 请输入统一密码 (如果不想设置密码,请直接按 Enter ): " unified_password
                if [ -z "$unified_password" ]; then
                    cmd="for r in $dirpath/*.rar; do rar x \$r -d $targetpath; done"
                else
                    cmd="for r in $dirpath/*.rar; do rar x -p'\$unified_password' \$r -d $targetpath; done"
                fi
                screen -dmS unrar_session bash -c "$cmd"
            else
                for r in "$dirpath"/*.rar; do
                    read -p " 为 $r 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                    if [ -z "$individual_password" ]; then
                        cmd="rar x $r -d $targetpath"
                    else
                        cmd="rar x -p'$individual_password' $r -d $targetpath"
                    fi
                    screen -dmS unrar_session bash -c "$cmd"
                done
            fi
            blue " 已在新的 screen 会话 unrar_session 中启动解压任务 "
            ;;

        7)
            # 批量压缩在screen会话中
            if ! command -v rar &> /dev/null || ! command -v screen &> /dev/null; then
                red " 您没有安装 rar 或 screen "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
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
                    cmd="for d in *; do if [ -d \$d ]; then rar a $destpath/\$d.rar \$d; fi; done"
                else
                    cmd="for d in *; do if [ -d \$d ]; then rar a -p'\$unified_password' $destpath/\$d.rar \$d; fi; done"
                fi
                screen -dmS rar_session bash -c "$cmd"
            else
                for d in *; do
                    if [ -d "$d" ]; then
                        read -p " 为 $d 输入密码 (如果不想设置密码,请直接按 Enter ): " individual_password
                        if [ -z "$individual_password" ]; then
                            cmd="rar a $destpath/$d.rar $d"
                        else
                            cmd="rar a -p'$individual_password' $destpath/$d.rar $d"
                        fi
                        screen -dmS rar_session bash -c "$cmd"
                    fi
                done
            fi

            popd > /dev/null

            blue " 已在新的 screen 会话 rar_session 中启动压缩任务 "
            ;;
        8)
            if ! command -v rar &> /dev/null && ! command -v unrar &> /dev/null; then
                red " 您没有安装 rar 或 unrar "
                red " 两秒后自动返回 "
                sleep 2
                rar_management
                return
            fi

            case $OS in
                ubuntu|debian)
                    blue " 将为您执行 $OS 下的 rar 和 unrar 卸载 "
                    sudo apt remove -y rar unrar
                    ;;
                centos|redhat)
                    blue " 将为您执行 $OS 下的 rar 和 unrar 手动卸载 "
                    sudo rm -f /usr/local/bin/rar
                    sudo rm -f /usr/local/bin/unrar
                    sudo rm -rf /usr/local/rar
                    ;;
                arch)
                    blue " 将为您执行 $OS 下的 rar 和 unrar 卸载 "
                    sudo pacman -R rar unrar
                    ;;
                *)
                    red " 不支持的操作系统 "
                    red " 两秒后自动返回 "
                    sleep 2
                    rar_management
                    return
                    ;;
            esac
            black " rar 和 unrar 卸载完成 "
            ;;
        0)
            # 返回应用程序菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字 "
            red " 两秒后自动返回 "
            sleep 2
            rar_management
            ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p " 按任意键返回菜单... "
    rar_management
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
    green " 1. 打开极光面板菜单 "
    yellow " =================================== "
    green " 0. 返回科学上网菜单 "
    echo
    read -p " 请输入数字: " menuNumberInput

    case "$menuNumberInput" in
        1)
            blue " 开始打开极光面板 "
            bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)
            blue " 极光面板打开完成 "
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
    green " 1. BBR加速 "
    green " 2. 设置时区 "
    green " 3. 设置swap "
    green " 4. IPv4/IPv6优先级调整 "
    green " 5. 配置IPv6 "
    green " 6. 融合怪ECS "
    green " 7. 流媒体检测 "
    green " 8. 游戏延迟检测 "

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
            Timezone_management
	;;
        3 )
            swap_management
	;;
        4 )
            network_management
    ;;
        5 )
            ipv6_management
    ;;
        6 )
            ecs_management
    ;;
        7 )
            mediacheck_management
    ;;
        8 )
            gamecheck_management
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
    green " 9. Nezha Panel "
    green " 10. Aria2 "
    green " 11. 7zip "
    green " 12. rar "

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
        9 )
            nezha_agent_management
    ;;
        10 )
            aria2_management
    ;;
        11 )
            7zip_management
    ;;
        12 )
            rar_management
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
    green " 1. 安装soga "
    green " 2. 安装XrayR "
    green " 3. 安装ss-go "
    green " 4. 安装极光面板 "


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
	orange " 1. 系统菜单 "
    orange " 2. 软件菜单 "
    orange " 3. 科学上网菜单 "
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


