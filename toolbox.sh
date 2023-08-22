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
bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}
orange(){
    echo -e "\033[38;5;208m\033[01m$1\033[0m"
}

# 系统设置

## BBR加速
function setup_bbr(){
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
        red " Error: Failed to download the script. Contact Rex to update the script URL. "
        return 1
    fi
    
    # 使脚本可执行
    chmod +x tcp.sh

    # 执行脚本
    ./tcp.sh

    # 可选：执行后删除脚本
    # rm -f tcp.sh
}
## 设置时区
function set_timezone(){
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " ============设置时区=============== "
    green " 1.设置时区为上海 "
    green " 2.设置时区为东京 "
    green " 3.设置时区为纽约 "
    green " 4.设置时区为洛杉矶 "
    green " 5.设置时区为伦敦 "
    green " 6.设置时区为巴黎 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================="
    green " 0. 返回系统设置菜单"
    echo
    read -p " 你的选择是: " menuNumberInput

    # 确保用户具有必要的权限
    if [ "$(id -u)" != "0" ]; then
        echo 
        red " 错误：此功能需要以root或sudo身份运行。"
        return 1
    fi

    # 检查timedatectl是否可用
    if ! command -v timedatectl &> /dev/null; then
        echo 
        red " 错误：此系统不支持timedatectl命令。"
        return 1
    fi

    case "$menuNumberInput" in
        1 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Asia/Shanghai'
            if [ "$current_timezone" == "$target_timezone" ]; then
                blue " 时区已经设置为 $target_timezone "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone。已将时区设置为 $target_timezone "
            fi
        ;;
        2 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Asia/Tokyo'
            if [ "$current_timezone" == "$target_timezone" ]; then
                blue " 时区已经设置为 $target_timezone "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone。已将时区设置为 $target_timezone "
            fi
        ;;
        3 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='America/New_York'
            if [ "$current_timezone" == "$target_timezone" ]; then
                blue " 时区已经设置为 $target_timezone "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone。已将时区设置为 $target_timezone "
            fi
        ;;
        4 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='America/Los_Angeles'
            if [ "$current_timezone" == "$target_timezone" ]; then
                blue " 时区已经设置为 $target_timezone "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone。已将时区设置为 $target_timezone "
            fi
        ;;
        5 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Europe/London'
            if [ "$current_timezone" == "$target_timezone" ]; then
                blue " 时区已经设置为 $target_timezone "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone。已将时区设置为 $target_timezone "
            fi
        ;;
        6 )
            current_timezone=$(timedatectl show --property=Timezone --value)
            target_timezone='Europe/Paris'
            if [ "$current_timezone" == "$target_timezone" ]; then
                blue " 时区已经设置为 $target_timezone "
            else
                timedatectl set-timezone "$target_timezone"
                blue " 当前时区为 $current_timezone。已将时区设置为 $target_timezone "
            fi
        ;;
        0 )
            # 返回系统菜单
            system_menu
            return 0
        ;;
        * )
            red " 无效的选择，请重新输入！ "
            red " 两秒后重新选择返回 "
            sleep 2s
            set_timezone
        ;;
    esac

    # 按任意键返回菜单
    read -n 1 -s -r -p "按任意键返回菜单..."
}
## 设置swap
function setup_swap() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    blue " 代码参考: https://github.com/spiritLHLS "
    yellow " ============设置swap=============== "
    green " 1.设置swap为1G "
    green " 2.设置swap为2G "
    green " 3.设置swap为4G "
    green " 4.自定义swap大小 "
    green " 5.删除swap "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================="
    green " 0. 返回系统设置菜单 "
    echo
    read -p " 你的选择是: " menuNumberInput

    # root权限检查
    if [[ $EUID -ne 0 ]]; then
        red "错误：此脚本必须以root权限运行！ "
        exit 1
    fi

    # 检测ovz
    if [[ -d "/proc/vz" ]]; then
        red "您的VPS基于OpenVZ，不支持！ "
        exit 1
    fi

    add_swap() {
        local swapsize=$1
        # 检查是否存在swapfile
        grep -q "swapfile" /etc/fstab

        # 如果不存在将为其创建swap
        if [ $? -ne 0 ]; then
            green "swapfile未发现，正在为其创建swapfile"
            fallocate -l ${swapsize}M /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap defaults 0 0' >> /etc/fstab
            green "swap创建成功，并查看信息："
            cat /proc/swaps
            cat /proc/meminfo | grep Swap
        else
            red "swapfile已存在，swap设置失败，请先删除当前swap后重新设置！ "
        fi
    }

    del_swap() {
        # 检查是否存在swapfile
        grep -q "swapfile" /etc/fstab

        # 如果存在就将其移除
        if [ $? -eq 0 ]; then
            green "swapfile已发现，正在将其移除..."
            sed -i '/swapfile/d' /etc/fstab
            echo "3" > /proc/sys/vm/drop_caches
            swapoff -a
            rm -f /swapfile
            green "swap已删除！ "
        else
            red "swapfile未发现，swap删除失败！ "
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
            green " 请输入需要添加的swap大小（单位：MB）："
            read -p " 请输入swap数值:" custom_swap_size
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
            red " 请输入正确数字！ "
            red " 两秒后自动返回 "
            sleep 2s
            setup_swap
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    setup_swap
}
## IPv4/IPv6优先级调整
function preferIPV4() {
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
    read -p "您的选择是: " isPreferIPv4Input
    case $isPreferIPv4Input in
        1)
            # 检查是否已经设置了 IPv4 优先
            if grep -qE "^[^#]*precedence ::ffff:0:0/96  100" /etc/gai.conf; then
                blue "您已经设置过优先使用 IPv4 了"
            else
                if grep -qE "^[^#]*label 2002::/16   2" /etc/gai.conf; then
                    blue "您已经设置过了 IPv6 优先, 本次清除了 IPv6 优先的设置"
                    sed -i '/label 2002::\/16   2/d' /etc/gai.conf
                fi
                # 设置 IPv4 优先
                echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
                blue "已经成功设置为 IPv4 优先"
            fi
            ;;
        2)
            # 检查是否已经设置了 IPv6 优先
            if grep -qE "^[^#]*label 2002::/16   2" /etc/gai.conf; then
                blue "您已经设置过优先使用 IPv6 了"
            else
                if grep -qE "^[^#]*precedence ::ffff:0:0/96  100" /etc/gai.conf; then
                    blue "您已经设置过了 IPv4 优先, 本次清除了 IPv4 优先的设置"
                    sed -i '/precedence ::ffff:0:0\/96  100/d' /etc/gai.conf
                fi
                # 设置 IPv6 优先
                echo "label 2002::/16   2" >> /etc/gai.conf
                blue "已经成功设置为 IPv6 优先"
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
            green "上面信息显示："
            green "如果是IPv4地址->则VPS服务器已设置为优先使用 IPv4"
            green "如果是IPv6地址->则VPS服务器已设置为优先使用 IPv6 "
            green " ===================================== "
            echo
            ;;
        0)
            # 返回系统菜单
            system_menu
            return 0
            ;;
        *)
            red " 无效的选择，请重新输入! "
            red " 两秒后自动返回 "
            sleep 2s
            preferIPV4
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    preferIPV4
}

# 安装包

## 安装nano
install_nano() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
    yellow " ============Nano菜单=============== "
    green " 1. 安装 Nano "
    green " 2. 使用 Nano 打开文件 "
    green " 3. 卸载 Nano "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================="
    green " 0. 返回系统设置菜单 "
    echo
    read -p " 你的选择是: " menuNumberInput

    case "$menuNumberInput" in
        1)
            if command -v nano &> /dev/null; then
                red "已经安装过nano了！"
                red " 两秒后自动返回 "
                sleep 2
                install_nano
                return
            fi
            
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                OS=$ID
            else
                OS=$(uname -s)
            fi

            blue "检测到您的系统为: $OS"

            case $OS in
                ubuntu|debian)
                    blue "将为您执行 $OS 下的 nano 安装"
                    sudo apt update
                    sudo apt install -y nano
                    ;;
                centos|redhat)
                    blue "将为您执行 $OS 下的 nano 安装"
                    sudo yum install -y nano
                    ;;
                arch)
                    blue "将为您执行 Arch Linux 下的 nano 安装"
                    sudo pacman -S nano
                    ;;
                *)
                    red "不支持的操作系统！ "
                    return 1
                    ;;
            esac
            blue "nano 安装完成！ "
            ;;
        2)
            if ! command -v nano &> /dev/null; then
                red "没有安装nano！请先安装。"
                install_nano
                return
            fi
            read -p "请输入您要使用nano打开的文件路径: " filepath
            nano $filepath
            ;;
        3)
            case $OS in
                ubuntu|debian)
                    blue "将为您执行 $OS 下的 nano 卸载"
                    sudo apt remove -y nano
                    ;;
                centos|redhat)
                    blue "将为您执行 $OS 下的 nano 卸载"
                    sudo yum remove -y nano
                    ;;
                arch)
                    blue "将为您执行 $OS 下的 nano 卸载"
                    sudo pacman -R nano
                    ;;
                *)
                    red "不支持的操作系统！ "
                    return 1
                    ;;
            esac
            blue "nano 卸载完成！ "
            ;;
        0)
            # 返回安装包菜单
            app_menu
            ;;
        *)
            red " 请输入正确数字！ "
            red " 两秒后自动返回 "
            sleep 2s
            install_nano
            ;;
    esac
    read -n 1 -s -r -p " 按任意键返回菜单... "
    install_nano
}

## 安装screen
install_screen() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue "检测到您的系统为: $OS"

    case $OS in
        ubuntu|debian)
            blue "将为您执行 $OS 下的 screen 安装"
            sudo apt update
            sudo apt install -y screen
            ;;
        centos|redhat)
            blue "将为您执行 $OS 下的 screen 安装"
            sudo yum install -y screen
            ;;
        arch)
            blue "将为您执行 Arch Linux 下的 screen 安装"
            sudo pacman -S screen
            ;;
        *)
            red "不支持的操作系统！ "
            return 1
            ;;
    esac
    blue "screen 安装完成！ "
    read -n 1 -s -r -p "按任意键返回主菜单..."
    app_menu
}
## 安装unzip
install_unzip() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue "检测到您的系统为: $OS"

    case $OS in
        ubuntu|debian)
            blue "将为您执行 $OS 下的 unzip 安装"
            sudo apt update
            sudo apt install -y unzip
            ;;
        centos|redhat)
            blue "将为您执行 $OS 下的 unzip 安装"
            sudo yum install -y unzip
            ;;
        arch)
            blue "将为您执行 Arch Linux 下的 unzip 安装"
            sudo pacman -S unzip
            ;;
        *)
            red "不支持的操作系统！ "
            return 1
            ;;
    esac
    blue "unzip 安装完成！ "
    read -n 1 -s -r -p "按任意键返回主菜单..."
    app_menu
}
## 安装wget, curl 和 git
install_wget_curl_git() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue "检测到您的系统为: $OS"

    case $OS in
        ubuntu|debian)
            blue "将为您执行 $OS 下的 wget, curl 和 git 安装"
            sudo apt update
            sudo apt install -y wget curl git
            ;;
        centos|redhat)
            blue "将为您执行 $OS 下的 wget, curl 和 git 安装"
            sudo yum install -y wget curl git
            ;;
        arch)
            blue "将为您执行 Arch Linux 下的 wget, curl 和 git 安装"
            sudo pacman -S wget curl git
            ;;
        *)
            red "不支持的操作系统！ "
            return 1
            ;;
    esac
    blue "wget, curl 和 git 安装完成！ "
    read -n 1 -s -r -p "按任意键返回主菜单..."
    app_menu
}
## 安装ca-certificates
install_ca_certificates() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue "检测到您的系统为: $OS"

    case $OS in
        ubuntu|debian)
            blue "将为您执行 $OS 下的 ca-certificates 安装"
            sudo apt update
            sudo apt install -y ca-certificates
            ;;
        centos|redhat)
            blue "将为您执行 $OS 下的 ca-certificates 安装"
            sudo yum install -y ca-certificates
            ;;
        arch)
            blue "将为您执行 Arch Linux 下的 ca-certificates 安装"
            sudo pacman -S ca-certificates
            ;;
        *)
            red "不支持的操作系统！ "
            return 1
            ;;
    esac
    blue "ca-certificates 安装完成！ "
    read -n 1 -s -r -p "按任意键返回主菜单..."
    app_menu
}

# 软件包

## 安装SpeedTest CLI
install_speedtest() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS=$(uname -s)
    fi

    blue "检测到您的系统为: $OS"

    case $OS in
        ubuntu|debian)
            # Ubuntu/Debian 安装指令
            blue "将为您执行 Ubuntu/Debian 下的 Speedtest CLI 安装"
            sudo apt-get install curl
            curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
            sudo apt-get install speedtest
            ;;
        fedora|centos|redhat)
            # Fedora/CentOS/RedHat 安装指令
            blue "将为您执行 Fedora/CentOS/RedHat 下的 Speedtest CLI 安装"
            curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
            sudo yum install speedtest
            ;;
        Darwin) # macOS
            # macOS 安装指令
            blue "将为您执行 macOS 下的 Speedtest CLI 安装"
            brew tap teamookla/speedtest
            brew update
            brew install speedtest --force
            ;;
        FreeBSD)
            # FreeBSD 安装指令
            blue "将为您执行 FreeBSD 下的 Speedtest CLI 安装"
            sudo pkg update && sudo pkg install -g libidn2 ca_root_nss
            # 这里我们检查FreeBSD的版本并执行相应的安装
            VERSION=$(uname -r | cut -d'.' -f1)
            if [[ $VERSION -eq 12 ]]; then
                sudo pkg add "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-freebsd12-x86_64.pkg"
            elif [[ $VERSION -eq 13 ]]; then
                sudo pkg add "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-freebsd13-x86_64.pkg"
            else
                red "不支持的 FreeBSD 版本!"
                return 1
            fi
            ;;
        *)
            red "不支持的操作系统！ "
            return 1
            ;;
    esac

    blue "Speedtest CLI 安装完成！ "
    blue "使用 speedtest 命令即可进行测速！ "
    read -n 1 -s -r -p "按任意键返回主菜单..."
    soft_menu
}
## 安装Caddy
install_caddy() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        OS=$(uname -s)
    fi

    blue "检测到您的系统为: $OS"

    case $OS in
        ubuntu|debian|raspbian)
            # Debian, Ubuntu, Raspbian 安装指令
            blue "将为您执行 Debian, Ubuntu, Raspbian 下的 Caddy 安装"
            sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
            sudo apt update
            sudo apt install caddy
            ;;
        fedora)
            # Fedora 安装指令
            blue "将为您执行 Fedora 下的 Caddy 安装"
            sudo dnf install 'dnf-command(copr)'
            sudo dnf copr enable @caddy/caddy
            sudo dnf install caddy
            ;;
        centos|redhat)
            # RHEL/CentOS 安装指令
            if [[ $VERSION_ID == 8* ]]; then
                blue "将为您执行 RHEL/CentOS 8 下的 Caddy 安装"
                sudo dnf install 'dnf-command(copr)'
                sudo dnf copr enable @caddy/caddy
                sudo dnf install caddy
            # RHEL/CentOS 7 安装指令
            elif [[ $VERSION_ID == 7* ]]; then
                blue "将为您执行 RHEL/CentOS 7 下的 Caddy 安装"
                sudo yum install yum-plugin-copr
                sudo yum copr enable @caddy/caddy
                sudo yum install caddy
            fi
            ;;
        arch|manjaro|parabola)
            # Arch Linux, Manjaro, Parabola 安装指令
            blue "将为您执行 Arch Linux, Manjaro, Parabola 下的 Caddy 安装"
            sudo pacman -Syu caddy
            ;;
        Darwin) # macOS
            # Homebrew (Mac) 安装指令
            blue "将为您执行 macOS 下的 Caddy 安装"
            brew install caddy
            ;;
        *)
            echo 
            red "不支持的操作系统！ "
            return 1
            ;;
    esac

    blue "Caddy 安装完成！ "
    read -n 1 -s -r -p "按任意键返回主菜单..."
    soft_menu
}
## 安装aapanel
install_aapanel() {
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo 
        red "无法检测您的操作系统类型！ "
        return 1
    fi

    blue "检测到您的系统为: $OS"

    case $OS in
        centos)
            # CentOS 安装指令
            blue "将为您执行 CentOS 下的 aapanel 安装"
            sudo yum install -y wget
            wget -O install.sh http://www.aapanel.com/script/install_6.0_en.sh
            bash install.sh aapanel
            ;;
        ubuntu|deepin)
            # Ubuntu/Deepin 安装指令
            blue "将为您执行 Ubuntu/Deepin 下的 aapanel 安装"
            wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh
            sudo bash install.sh aapanel
            ;;
        debian)
            # Debian 安装指令
            blue "将为您执行 Debian 下的 aapanel 安装"
            wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh
            bash install.sh aapanel
            ;;
        *)
            red "不支持的操作系统！ "
            return 1
            ;;
    esac

    blue "aapanel 安装完成！ "
    blue "使用 bt 命令查看 aapanel 菜单"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    soft_menu
}

# 科学上网

## 安装soga
install_soga() {
    # 安装 soga
    blue "开始安装 soga..."
    bash <(curl -Ls https://github.com/sprov065/soga/raw/master/soga.sh)

    blue "soga 安装完成！ "
    blue "使用 soga 查看 soga 菜单"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    vpn_menu
}
## 安装XrayR
install_XrayR() {
    # 安装 XrayR
    blue "开始安装 XrayR..."
    bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)

    blue "XrayR 安装完成！ "
    blue "使用 XrayR update 或 xrayr update 更新"
    blue "使用 XrayR 或 xrayr 查看 XrayR 菜单"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    vpn_menu
}
## 安装ss-go
install_ss_go() {
    # 下载并安装 ss-go
    blue "开始安装 ss-go..."
    wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ss-go.sh
    chmod +x ss-go.sh
    bash ss-go.sh

    blue "ss-go 安装完成！ "
    blue "使用 ./ss-go.sh 查看 ss-go 菜单"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    vpn_menu
}
## 安装极光面板
install_aurora_admin_panel() {
    # 安装 Aurora Admin Panel
    blue "开始安装极光面板"
    bash <(curl -fsSL https://raw.githubusercontent.com/Aurora-Admin-Panel/deploy/main/install.sh)

    blue "极光面板安装完成！ "
    read -n 1 -s -r -p "按任意键返回主菜单..."
    vpn_menu
}

# 菜单

# 系统设置菜单
system_menu() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " =======ToolBox系统设置菜单========== "
    green " 1.BBR加速 "
    green " 2.设置时区 "
    green " 3.设置swap "
    green " 4.IPv4/IPv6优先级调整 "

    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " =================================== "
    green " 0. 返回主菜单"
    echo
    read -p " 请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            setup_bbr
	;;
        2 )
            set_timezone
	;;
        3 )
            setup_swap
	;;
        4 )
            preferIPV4
    ;;
        0 )
            start_menu
    ;;
        * )
            clear
            red " 请输入正确数字 ! "
            red " 两秒后自动返回 "
            sleep 2s
            system_menu
        ;;
    esac
}
# 安装包菜单
app_menu() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " =========ToolBox软件包菜单========== "
    green " 1.安装nano "
    green " 2.安装screen "
    green " 3.安装unzip "
    green " 4.安装wget, curl 和 git "
    green " 5.安装ca-certificates "

    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================== "
    green " 0. 返回主菜单"
    echo
    read -p " 请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            install_nano
	;;
        2 )
            install_screen
	;;
        3 )
            install_unzip
	;;
        4 )
            install_wget_curl_git
    ;;
        5 )
            install_ca_certificates
    ;;
        0 )
            start_menu
    ;;
        * )
            clear
            red " 请输入正确数字 ! "
            red " 两秒后自动返回 "
            sleep 2s
            app_menu
        ;;
    esac
}
# 软件菜单
soft_menu() {
    clear
    blue " Rex Lee's ToolBox " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " =========ToolBox软件菜单============ "
    green " 1.安装SpeedTest CLI "
    green " 2.安装Caddy "
    green " 3.安装aapanel "


    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================== "
    green " 0. 返回主菜单"
    echo
    read -p " 请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            install_speedtest
	;;
        2 )
            install_caddy
	;;
        3 )
            install_aapanel
	;;
        0 )
            start_menu
    ;;
        * )
            clear
            red " 请输入正确数字 ! "
            red " 两秒后自动返回 "
            sleep 2s
            soft_menu
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
    read -p " 请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            install_soga
	;;
        2 )
            install_XrayR
	;;
        3 )
            install_ss_go
	;;
        4 )
            install_aurora_admin_panel
    ;;
        0 )
            start_menu
    ;;
        * )
            clear
            red " 请输入正确数字 ! "
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
	orange " 1.系统设置菜单 "
    orange " 2.安装包菜单 "
    orange " 3.软件菜单 "
    orange " 4.科学上网菜单 "
    echo
    orange " 为保证有权限执行,请使用root用户运行 "
    yellow " ==================================== "
    green " 0. 退出脚本"
    echo
    read -p " 请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            system_menu
	;;
        2 )
            app_menu
	;;
        3 )
            soft_menu
	;;
        4 )
            vpn_menu
    ;;
        0 )
            exit 1
    ;;
        * )
            clear
            red " 请输入正确数字 ! "
            red " 两秒后自动返回主菜单"
            sleep 2s
            start_menu
        ;;
    esac
}

start_menu

