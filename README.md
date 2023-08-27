# Rex Lee's ToolBox 

```
wget -O toolbox.sh https://raw.githubusercontent.com/RexLee0929/VPS/main/toolbox.sh && chmod +x toolbox.sh && clear && ./toolbox.sh
```

## 现已支持
![image](https://github.com/RexLee0929/VPS/assets/62170324/8e23c288-5a75-4337-b39f-c3b6b0c1dd5e)

![image](https://github.com/RexLee0929/VPS/assets/62170324/8d92227f-c02a-4fb2-88e4-b9ba7fa853d6)

![image](https://github.com/RexLee0929/VPS/assets/62170324/68539c5b-a62f-47c7-a8d4-7b46a88d403f)

## 即将支持

Ubuntu 使用 netplan 配置ipv6

rar

7z

renamer

rclone

挂载硬盘 

docker 

....
















## 基础

### 创建root用户密码

```
echo root:'密码' |sudo chpasswd root
sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
sudo service sshd restart
```

### 安装unrar

***CentOS***

下载rar安装包

```
wget https://www.rarlab.com/rar/rarlinux-x64-6.0.2.tar.gz --no-check-certificate
```

解压压缩包到/usr/local下

```
tar zxvf rarlinux-x64-6.0.2.tar.gz -C /usr/local
```

将 rar 和 unrar 命令链接到/usr/local/bin目录下

```
ln -s /usr/local/rar/rar /usr/local/bin/rar
ln -s /usr/local/rar/unrar /usr/local/bin/unrar
```

***Ubuntu***

```
apt-get install -y unrar
apt-get install -y rar
```

查看帮助文档

```
rar --help
unrar --help
```

使用方法

```
unrar x '文件目路径.rar' '保存的路径'
```

### 安装7zip

***CentOS***

```
yum install -y epel-release
yum install -y p7zip p7zip-plugins
```

***Ubuntu***

```
add-apt-repository universe
apt install -y p7zip-full p7zip-rar
```

使用方法

```
7z x '压缩文件路径' -r -o/'需要保存到的路径'
```

解压目录下所有.7z 密码为`password`

```
find . -name "*.7z" | while read filename; do 7z x -p'password' "$filename" -o"$(dirname "$filename")" ; done
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

### 流媒体检测

```
bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh)
```

### 多维度测试VPS

```
bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh)
```

### 测试部分游戏延迟

```
bash <(curl -L -s https://raw.githubusercontent.com/lmc999/GamePing/main/GamePing.sh)
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
