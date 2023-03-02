# VPS 自用常用脚本

## 基础

### 创建root用户密码
```
echo root:'密码' |sudo chpasswd root
sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
sudo service sshd restart
```

### 安装curl和weget
***Centos***
```
yum install -y curl wget 2> /dev/null
```
***Ubuntu***
```
apt install -y curl wget
```

### 安装ca-certificates
***Centos***
```
yum install -y ca-certificates
```
```
apt install -y ca-certificates
```

### 管理BBR加速
首次使用
```
wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```
后续使用
```
./tcp.sh
```

### 安装哪吒面板

首次使用
```
curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -o nezha.sh && chmod +x nezha.sh && ./nezha.sh
```
后续使用
```
./nezha.sh
```

### 安装screen
***Centos***
```
yum install -y screen
```
***Ubuntu***
```
apt install -y screen
```
使用方法
```
screen #创建一个新的窗口
screen -ls #列出所有窗口
screen -wipe #删除Dead窗口
screen -r 123 #回到窗口123
screen -d 123 #分离123 窗口
screen -S 123 -X quit #杀死窗口123
```

### 安装nano编辑器
***Centos***
```
yum install -y nano
```
***Ubuntu***
```
apt install -y nano
```

### 安装unzip
***Centos***
```
yum install -y unzip
```
***Ubuntu***
```
apt install -y unzip
```

### 安装unrar
***Centos***
下载rar安装包
```
wget http://www.rarlab.com/rar/rarlinux-x64-621.tar.gz --no-check-certificate
```
解压压缩包到/usr/local下
```
tar zxvf rarlinux-x64-621.tar.gz -C /usr/local
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
***Centos***
```
yum install -y epel-release
yum install -y p7zip p7zip-plugins
```
un7zip 使用方法
```
7z x '压缩文件路径' -r -o/'需要保存到的路径'
```

## 常用应用
### Aria2
为了确保能正常使用，请先安装基础组件wget、curl、ca-certificates
```
yum install -y wget curl ca-certificates #Centos
apt install -y wget curl ca-certificates #Ubuntu
```
下载脚本
```
wget -N git.io/aria2.sh && chmod +x aria2.sh
```
运行脚本
```
./aria2.sh
```
修改配置文件
```
nano /root/.aria2c/aria2.conf
```
配置完成下载后自动上传
找到“下载完成后执行的命令”，把clean.sh替换为upload.sh
```
on-download-complete=/root/.aria2c/upload.sh
```
修改附加脚本配置
```
nano /root/.aria2c/script.conf
```
修改完成后重启Aria2
```
service aria2 restart
```
检查配置是否成功
```
/root/.aria2c/upload.sh
```

