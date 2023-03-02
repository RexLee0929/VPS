# VPS 自用常用脚本

## 基础

-  ### 创建root用户密码
```
echo root:'密码' |sudo chpasswd root
sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
sudo service sshd restart
```

-  ### 安装curl和weget
***Centos***
```
yum install -y curl wget 2> /dev/null
```
***Ubuntu***
```
apt install -y curl wget
```

-  ### 安装ca-certificates
***Centos***
```
yum install -y ca-certificates
```
```
apt install -y ca-certificates
```

-  ### 管理BBR加速
首次使用
```
wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
```
后续使用
```
./tcp.sh
```

-  ### 安装哪吒面板

首次使用
```
curl -L https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -o nezha.sh && chmod +x nezha.sh && ./nezha.sh
```
后续使用
```
./nezha.sh
```

-  ### 安装screen
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

-  ### 安装nano编辑器
***Centos***
```
yum install -y nano
```
***Ubuntu***
```
apt install -y nano
```

-  ### 安装unzip
***Centos***
```
yum install -y unzip
```
***Ubuntu***
```
apt install -y unzip
```

-  ### 安装unrar
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
-  ### 安装7zip
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
-  ### Aria2
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

找到“**下载完成后执行的命令**”，把**clean**.sh替换为**upload**.sh
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
-  ### Rclone

一键安装Rclone
```
curl https://rclone.org/install.sh | sudo bash
```
配置Rclone
```
rclone config
```

[root@centos-s-1vcpu-2gb-amd-sfo3-01 ~]# rclone config
No remotes found, make a new one?
n) New remote
s) Set configuration password
q) Quit config
n/s/q> n #创建新的配置

Enter name for new remote.
name> OneDrive #输入配置标签

Option Storage.
Type of storage to configure.
Choose a number from below, or type in your own value.
 1 / 1Fichier
   \ (fichier)
 2 / Akamai NetStorage
   \ (netstorage)
 3 / Alias for an existing remote
   \ (alias)
 4 / Amazon Drive
   \ (amazon cloud drive)
 5 / Amazon S3 Compliant Storage Providers including AWS, Alibaba, Ceph, China Mobile, Cloudflare, ArvanCloud, DigitalOcean, Dreamhost, Huawei OBS, IBM COS, IDrive e2, IONOS Cloud, Liara, Lyve Cloud, Minio, Netease, RackCorp, Scaleway, SeaweedFS, StackPath, Storj, Tencent COS, Qiniu and Wasabi
   \ (s3)
 6 / Backblaze B2
   \ (b2)
 7 / Better checksums for other remotes
   \ (hasher)
 8 / Box
   \ (box)
 9 / Cache a remote
   \ (cache)
10 / Citrix Sharefile
   \ (sharefile)
11 / Combine several remotes into one
   \ (combine)
12 / Compress a remote
   \ (compress)
13 / Dropbox
   \ (dropbox)
14 / Encrypt/Decrypt a remote
   \ (crypt)
15 / Enterprise File Fabric
   \ (filefabric)
16 / FTP
   \ (ftp)
17 / Google Cloud Storage (this is not Google Drive)
   \ (google cloud storage)
18 / Google Drive
   \ (drive)
19 / Google Photos
   \ (google photos)
20 / HTTP
   \ (http)
21 / Hadoop distributed file system
   \ (hdfs)
22 / HiDrive
   \ (hidrive)
23 / In memory object storage system.
   \ (memory)
24 / Internet Archive
   \ (internetarchive)
25 / Jottacloud
   \ (jottacloud)
26 / Koofr, Digi Storage and other Koofr-compatible storage providers
   \ (koofr)
27 / Local Disk
   \ (local)
28 / Mail.ru Cloud
   \ (mailru)
29 / Mega
   \ (mega)
30 / Microsoft Azure Blob Storage
   \ (azureblob)
31 / Microsoft OneDrive
   \ (onedrive)
32 / OpenDrive
   \ (opendrive)
33 / OpenStack Swift (Rackspace Cloud Files, Memset Memstore, OVH)
   \ (swift)
34 / Oracle Cloud Infrastructure Object Storage
   \ (oracleobjectstorage)
35 / Pcloud
   \ (pcloud)
36 / Put.io
   \ (putio)
37 / QingCloud Object Storage
   \ (qingstor)
38 / SMB / CIFS
   \ (smb)
39 / SSH/SFTP
   \ (sftp)
40 / Sia Decentralized Cloud
   \ (sia)
41 / Storj Decentralized Cloud Storage
   \ (storj)
42 / Sugarsync
   \ (sugarsync)
43 / Transparently chunk/split large files
   \ (chunker)
44 / Union merges the contents of several upstream fs
   \ (union)
45 / Uptobox
   \ (uptobox)
46 / WebDAV
   \ (webdav)
47 / Yandex Disk
   \ (yandex)
48 / Zoho
   \ (zoho)
49 / premiumize.me
   \ (premiumizeme)
50 / seafile
   \ (seafile)
Storage> 31 #选择网盘编号

Option client_id.
OAuth Client Id.
Leave blank normally.
Enter a value. Press Enter to leave empty.
client_id> #留空

Option client_secret.
OAuth Client Secret.
Leave blank normally.
Enter a value. Press Enter to leave empty.
client_secret> #留空

Option region.
Choose national cloud region for OneDrive.
Choose a number from below, or type in your own string value.
Press Enter for the default (global).
 1 / Microsoft Cloud Global
   \ (global)
 2 / Microsoft Cloud for US Government
   \ (us)
 3 / Microsoft Cloud Germany
   \ (de)
 4 / Azure and Office 365 operated by Vnet Group in China
   \ (cn)
region> 1 #选择你的网盘账号对应的信息 

Edit advanced config?
y) Yes
n) No (default)
y/n> n #选n  

Use web browser to automatically authenticate rclone with remote?
 * Say Y if the machine running rclone has a web browser you can use
 * Say N if running rclone on a (remote) machine without web browser access
If not sure try Y. If Y failed, try N.

y) Yes (default)
n) No
y/n> n #选n

Option config_token.
For this to work, you will need rclone available on a machine that has
a web browser available.
For more help and alternate methods see: https://rclone.org/remote_setup/
Execute the following on the machine with the web browser (same rclone
version recommended):
        rclone authorize "onedrive" "eyJjbGllbnRfaWQiOiIj55WZ56m6IiwiY2xpZW50X3NlY3JldCI6IiPnlZnnqboiLCJyZWdpb24iOiIxICPpgInmi6nkvaDnmoTnvZHnm5jotKblj7flr7nlupTnmoTlubhcdWZmZmTkv6Hmga8ifQ"
Then paste the result.
Enter a value.
config_token> {"XXX省略"} #粘贴你的token

Option config_type.
Type of connection
Choose a number from below, or type in an existing string value.
Press Enter for the default (onedrive).
 1 / OneDrive Personal or Business
   \ (onedrive)
 2 / Root Sharepoint site
   \ (sharepoint)
   / Sharepoint site name or URL
 3 | E.g. mysite or https://contoso.sharepoint.com/sites/mysite
   \ (url)
 4 / Search for a Sharepoint site
   \ (search)
 5 / Type in driveID (advanced)
   \ (driveid)
 6 / Type in SiteID (advanced)
   \ (siteid)
   / Sharepoint server-relative path (advanced)
 7 | E.g. /teams/hr
   \ (path)
config_type> 1 #选择你的网盘类型

Option config_driveid.
Select drive you want to use
Choose a number from below, or type in your own string value.
Press Enter for the default (b!gNjH6y4lJkSOIwwgfe400rd15OglZflKihubYX-n6JHWlCUI5czHS5LJv7ay4wgb).
 1 / OneDrive (business)
   \ (b!gNjH6y4lJkSOIwwgfe400rd15OglZflKihubYX-n6JHWlCUI5czHS5LJv7ay4wgb)
config_driveid> #回车

Drive OK?

Found drive "root" of type "business"
URL: https://t27hg-my.sharepoint.com/personal/rexlee_t27hg_onmicrosoft_com/Documents

y) Yes (default)
n) No
y/n> #回车

Keep this "sadasda" remote?
y) Yes this is OK (default)
e) Edit this remote
d) Delete this remote
y/e/d> #回车


