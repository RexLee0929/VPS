# Rex Lee's ToolBox 

```
bash <(curl -sSL https://raw.githubusercontent.com/RexLee0929/VPS/main/toolbox.sh)
```
## Start 脚本

```
curl -L "https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/start.sh" -o start.sh && chmod +x start.sh && ./start.sh -f 环境变量下载地址 -R dns前缀 -S soga节点id -V vmess节点id -K 哪吒key
```

## DDNS 脚本

下载脚本并且给予运行权限

```
wget https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/ddns.sh && chmod +x ddns.sh
```

修改里面的参数,不强制修改,可以在执行的时候加上参数

```
nano ./ddns.sh
```

运行脚本

```
./ddns.sh
```

```
./ddns.sh -k "key" -u "mail" -z "domain.com" -h "sg.domian.com" -t "A" -l "120" -p "false"
```

写入定时脚本

```
*/2 * * * * /root/ddns.sh -k "key" -u "mail" -z "domain.com" -h "sg.domian.com" -t "A" -l "120" -p "false" | sed 's/\x1b\[[0-9;]*m//g' >> /root/ddns.log 2>&1
```


## 现已支持
![image](https://github.com/RexLee0929/VPS/assets/62170324/8e23c288-5a75-4337-b39f-c3b6b0c1dd5e)

![image](https://github.com/RexLee0929/VPS/assets/62170324/8d92227f-c02a-4fb2-88e4-b9ba7fa853d6)

![image](https://github.com/RexLee0929/VPS/assets/62170324/68539c5b-a62f-47c7-a8d4-7b46a88d403f)

## 即将支持

Ubuntu 使用 netplan 配置ipv6

renamer

rclone

挂载硬盘 

docker 

....




php artisan v2board:update











## 基础

### 创建root用户密码

```
echo root:'密码' |sudo chpasswd root
sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
sudo service sshd restart
```

## 常用应用

## Aria2 配置参考

[Aria2.conf](https://github.com/Rex0929/VPS/blob/main/aria2.conf)

[Script.conf](https://github.com/Rex0929/VPS/blob/main/script.conf)

### Rclone

一键安装Rclone

```
curl https://rclone.org/install.sh | sudo bash
```

配置Rclone

```
rclone config
```

Rclone 配置参考

[参考配置](https://github.com/Rex0929/VPS/blob/main/Rclone.md)

### 使用Rclone将文件上传至网盘

使用screen后台上传

```
screen rclone move -v /DISK/downloads OneDriveE51:/upload --transfers 2 -P
```
### Qbittorrent-nox

***Ubuntu***

创建systemctl任务
```
cat > /etc/systemd/system/qbittorrent-nox.service <<EOF
[Unit]
Description=qBittorrent-nox
After=network.target
[Service]
User=root
Type=forking
RemainAfterExit=yes
ExecStart=/usr/bin/qbittorrent-nox -d
[Install]
WantedBy=multi-user.target

EOF
```

### 安装Socks5代理

下载脚本

```
wget --no-check-certificate https://raw.github.com/Lozy/danted/master/install.sh -O install.sh
```

安装脚本

```
bash install.sh  --port=运行端口 --user=用户名 --passwd=密码
```

卸载脚本

```
bash install.sh --uninstall
```

### 一键WARP脚本

```
wget -N https://cdn.jsdelivr.net/gh/fscarmen/warp/menu.sh && bash menu.sh
```

WARP菜单

```
bash menu.sh
```

### Prename

***CentOS***

```
yum install -y epel-release
yum install -y prename
```

使用方法

```
prename -v 's/原字符串表达式1/目标字符串表达式2/' 文件(列表)
```

### Rename

***Ubuntu***

```
apt install -y rename
```

使用方法

```
rename 原字符串 目标字符串 文件(列表)
```

### BestTrace

下载脚本

```
wget https://cdn.ipip.net/17mon/besttrace4linux.zip
mkdir besttrace
unzip besttrace4linux.zip -d ./besttrace
cd besttrace
chmod 755 besttrace
```

运行脚本

```
./besttrace/besttrace -q 1 'Your=IP'
```

## 系统

### 防火墙

***CentOS***

查看防火墙状态

```
systemctl status firewalld
```

开启防火墙

```
systemctl start firewalld
```

临时关闭命令

```
systemctl stop firewalld
```

永久关闭命令

```
systemctl disable firewalld
```

***Ubuntu***

打开防火墙

```
sudo ufw enable
```

关闭防火墙

```
sudo ufw disable
```

### iptables

开放所有端口

```
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
```

### Oracle

***CentOS***

删除多余附件

```
systemctl stop oracle-cloud-agent
systemctl disable oracle-cloud-agent
systemctl stop oracle-cloud-agent-updater
systemctl disable oracle-cloud-agent-updater
```

停止防火墙并禁止自启动

```
systemctl stop firewalld.service
systemctl disable firewalld.service
```

***Ubuntu***

开放所有端口

```
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
```

关闭防火墙

```
apt-get purge netfilter-persistent && reboot
```

强制删除防火墙

```
rm -rf /etc/iptables && reboot
```

### BuyVM

### IPV6

***CentOS***

```
cd /etc/sysconfig/network-scripts
```
修改 `ifcfg-eth0` 文件

[参考配置](https://github.com/Rex0929/VPS/blob/main/centos7-ipv6)

编辑 `/etc/resolv.conf` 文件

添加

```
nameserver 2001:4860:4860::8888
nameserver 2001:4860:4860::8844
```

重启网络

```
service network restart
```

***Ubuntu***

```
cd /etc/netplan
```

修改 `01-netcfg.yaml` 文件

[Ubuntu20参考配置](https://github.com/Rex0929/VPS/blob/main/ubuntu20-ipv6)

[Ubuntu22参考配置](https://github.com/Rex0929/VPS/blob/main/ubuntu22-ipv6)

检查配置文件

```
sudo netplan try
```

应用更改

```
sudo netplan apply
```


### 挂载硬盘

查看硬盘盘序列号:

```
ls /dev/disk/by-id/
```

格式化硬盘

```
mkfs.ext4 -F /dev/disk/by-id/scsi-0BUYVM_SLAB_VOLUME-16092
```

创建挂载目录

```
mkdir -p /DISK
```

挂载硬盘到 `DISK` 目录：

```
mount -o discard,defaults /dev/disk/by-id/scsi-0BUYVM_SLAB_VOLUME-16092 /DISK
```

查看挂载结果

```
df -h
```

给予文件夹读写权限

```
chmod -R 777 /DISK/
```

设置开机自动挂载硬盘

***CentOS***

```
echo "/dev/disk/by-id/scsi-0BUYVM_SLAB_VOLUME-16092 /DISK ext4 defaults 0 0" >> /etc/fstab
```

***Ubuntu***

```
echo '/dev/disk/by-id/scsi-0BUYVM_SLAB_VOLUME-16092 /DISK ext4 defaults,nofail,discard 0 0' | sudo tee -a /etc/fstab
```

### 修改系统编码

修改  `/etc/locale.gen`文件

```
nano /etc/locale.gen
```

找到以下两行，并将其前面的注释'#'去掉。

```
en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
```

运行以下命令生成新的系统编码。

```
sudo locale-gen
```

运行以下命令更新系统编码设置

```
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
```

***CentOS***

安装中文字体库

```
yum install -y fontconfig
```

执行以下命令，更新字体缓存

```
fc-cache -fv
```

修改文件`/etc/locale.conf`为

```
LANG="en_US.UTF-8"
LC_ALL="en_US.UTF-8"
LANG="zh_CN.UTF-8"
LC_ALL="zh_CN.UTF-8"
```

执行

```
source /etc/locale.conf
```

重启

```
reboot
```

***Ubuntu***

```
sudo dpkg-reconfigure locales
```

把要启用的语言使用 'Space' 键选中 'Enter' 键确认



## Docker

### 启动docker-compose

```
docker-compose up -d
```

### 列出所有容器

```
docker ps -a
```

### 查看镜像

```
docker images
```

### 删除特定的Docker镜像

```
docker rmi <镜像名称1> <镜像名称2>
```

### 删除已经停止的容器

```
docker rm <容器ID>
```

### 清除容器缓存

```
docker system prune
```
