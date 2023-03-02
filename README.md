# VPS 自用常用脚本

## 开机必装

### 安装curl和weget

```
yum install -y curl wget 2> /dev/null || apt install -y curl wget
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

```
yum -y install screen
```

### 安装nano编辑器

```
yum -y install nano
```

### 安装unzip

```
yum -y install unzip
```

### 安装unrar

```

```


### 安装7z

```
yum -y install epel-release
yum -y install p7zip p7zip-plugins
```
使用方法
```
7z x 压缩文件地址 -r -o/需要保存到的文件地址
```

### 管

```

```


### 管

```

```


### 管

```

```
