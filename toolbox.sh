#by Rex Lee


##脚本所用到的颜色

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

#系统相关

## BBR加速
function bbr(){
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

function set_shanghai_timezone(){
    # 确保用户具有必要的权限
    if [ "$(id -u)" != "0" ]; then
        echo 
        red " Error: This function needs to be run as root or with sudo. "
        return 1
    fi

    # 检查timedatectl是否可用
    if ! command -v timedatectl &> /dev/null; then
        echo 
        red " Error: timedatectl is not available on this system. "
        return 1
    fi

    # 设置时区为上海
    timedatectl set-timezone 'Asia/Shanghai'
    echo 
    blue " Timezone has been set to Asia/Shanghai "

    # 按任意键返回主菜单
    read -n 1 -s -r -p "按任意键返回主菜单..."
    start_menu
}

## 设置swap
function setup_swap() {
    # 检查curl是否已安装
    if ! command -v curl &> /dev/null; then
        echo 
        red " Error: curl is not installed. Please install it first. "
        return 1
    fi

    # 使用curl下载脚本
    if ! wget -4 -N --no-check-certificate "https://raw.githubusercontent.com/spiritLHLS/lxd/main/scripts/swap.sh"; then
        echo 
        red " Error: Failed to download the script. Contact Rex to update the script URL. "
        return 1
    fi

    # 检查下载的内容是否为HTML
    if grep -q '<!doctype html>' swap.sh; then
        echo 
        red " Error: The downloaded content is not a valid script. Contact Rex to update the script URL. "
        return 1
    fi

    # 使脚本可执行
    chmod +x swap.sh

    # 执行脚本
    ./swap.sh
}

## IPv4/IPv6优先级调整
function preferIPV4() {
    while true; do
        clear
        blue " Rex 常用脚本 "
        blue " GitHub: https://github.com/RexLee0929 "
        green " =======IPv4/IPv6优先级调整============== "
        yellow " 请为服务器设置优先使用 IPv4 还是 IPv6 : "
        echo
        green " 1. 优先使用 IPv4 "
        green " 2. 优先使用 IPv6 "
        green " 3. 删除优先使用 IPv4 或 IPv6 的设置, 还原为系统默认配置 "
        green " 4. 验证 IPv4 或 IPv6 的优先级 "
        echo
        yellow " =============================================== "
        green " 0. 返回上级菜单 "
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
                blue " Rex 常用脚本 "
                blue " GitHub: https://github.com/RexLee0929 "
                green " =======IPv4/IPv6优先级调整============== "
                green " ============验证 IPv4 或 IPv6 的优先级============ "
                echo
                yellow " 验证 IPv4 或 IPv6 的优先级测试, 命令: curl ip.p3terx.com "
                echo
                curl ip.p3terx.com
                echo
                green "上面信息显示："
                green "如果是IPv4地址->则VPS服务器已设置为优先使用 IPv4"
                green "如果是IPv6地址->则VPS服务器已设置为优先使用 IPv6 "
                green " ================================================ "
                echo
                ;;
            0)
                # 退出菜单
                break
                ;;
            *)
                red " 无效的选择，请重新输入! "
                ;;
        esac
        read -n 1 -s -r -p " 按任意键返回菜单... "
    done
    start_menu
}

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
            red "不支持的操作系统！"
            return 1
            ;;
    esac

    blue "Speedtest CLI 安装完成！"
    blue "使用 speedtest 命令即可进行测速！"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    start_menu
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
            red "不支持的操作系统！"
            return 1
            ;;
    esac

    blue "Caddy 安装完成！"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    start_menu
}


#主菜单
function start_menu(){
    clear
    blue " Rex 常用脚本 " 
    blue " GitHub: https://github.com/RexLee0929 "
	yellow " =======本机系统相关============================== "
    green " 1. BBR加速 "
    green " 2. 设置时区为上海 "
    green " 3. 设置swap(相当于Windos的虚拟内存) "
    green " 4. ipv4/6优先级调整 "
    green " 5. 安装SpeedTest CLI "
    green " 6. 安装Caddy "


    orange " 本脚本为保证权限,请在root用户下执行 "
    yellow " =============================================== "
    green " 0. 退出脚本"
    echo
    read -p "请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
           bbr
	;;
        2 )
           set_shanghai_timezone
    ;;
        3 )
           setup_swap
    ;;
        4 )
           preferIPV4 "redo"
    ;;
        5 )
           install_speedtest
    ;;
        6 )
           install_caddy
    ;;
        0 )
            exit 1
    ;;
        * )
            clear
            red "请输入正确数字 ! "
            red "两秒后自动返回主菜单"
            sleep 2s
            start_menu
        ;;
    esac
}


start_menu "first"

