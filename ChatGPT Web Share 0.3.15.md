ChatGPT Web Share 0.3.15

# 使用 Docker 部署

首先你需要创建一个文件夹用于存放配置文件

```
mkdir ChatGPT-Share
cd ChatGPT-Share
```

## 部署在同一台服务器上

### 创建`docker-compose.yml`配置

假如你只有一个openai账号需要部署

version: "3"

```
services:
  chatgpt-share:
    image: ghcr.io/moeakwak/chatgpt-web-share:latest
    restart: always
    ports:
      - 8080:80 # web 端口号
    volumes:
      - ./data:/data # 存放数据库文件以及统计数据
      - ./config.yaml:/app/backend/api/config/config.yaml # 后端配置文件
      - ./logs:/app/logs # 存放日志文件
    environment:
      - TZ=Asia/Shanghai
      - CHATGPT_BASE_URL=http://go-chatgpt-api:8080/chatgpt/
    depends_on:
      - go-chatgpt-api

  go-chatgpt-api:
    image: linweiyuan/go-chatgpt-api:latest
    ports:
      - 6060:8080 # 如果你需要暴露端口如一带多，可以取消注释
    environment:
      - GIN_MODE=release
      - CHATGPT_PROXY_SERVER=http://chatgpt-proxy-server:9515
      # - NETWORK_PROXY_SERVER=http://host:port
    restart: unless-stopped
```

假如你有多个openai账号需要部署,这时就可以使用以下配置,避免重复运行`go-chatgpt-api`

```
version: "3"

services:
  chatgpt-share:
    image: ghcr.io/moeakwak/chatgpt-web-share:latest
    container_name: chatgpt-web-share
    restart: always
    network_mode: bridge
    ports:
      - 8080:80 # web 端口号
    volumes:
      - ./data:/data # 存放数据库文件以及统计数据
      - ./config.yaml:/app/backend/api/config/config.yaml # 后端配置文件
      - ./logs:/app/logs # 存放日志文件
```

具体端口自行修改

新建一个文件夹用于存放`go-chatgpt-api`

```
cd ~
mkdir go-chatgpt-api
cd go-chatgpt-api
```

创建`docker-compose.yml`配置

```
version: "3"

services:
  go-chatgpt-api:
    container_name: go-chatgpt-api
    image: linweiyuan/go-chatgpt-api
    ports:
      - 6060:8080
    environment:
      - GO_CHATGPT_API_PROXY=
    restart: unless-stopped
```

### 配置`config.yaml`

将`config.yaml`文件放在`ChatGPT-Share`文件夹内如是分离部署`go-chatgpt-api`也只放在`ChatGPT-Share`内

```
print_sql: false
host: "127.0.0.1"
port: 8010
data_dir: /data # <------ v0.3.0 以上新增
database_url: "sqlite+aiosqlite:////data/database.db" # 特别注意：这里有四个斜杠，代表着文件位于 /data 目录，使用的是绝对路径
run_migration: false # 是否在启动时运行数据库迁移，目前没有必要启用

jwt_secret: "你的 jwt secret" # 用于生成 jwt token，自行填写随机字符串
jwt_lifetime_seconds: 86400 # jwt token 过期时间
cookie_max_age: 86400 # cookie 过期时间
user_secret: "你的 user secret" # 用于生成用户密码，自行填写随机字符串

sync_conversations_on_startup: true # 是否在启动时同步同步 ChatGPT 对话，建议启用。启用后，将会自动将 ChatGPT 中新增的对话同步到数据库中，并把已经不在 ChatGPT 中的对话标记为无效
create_initial_admin_user: true # 是否创建初始管理员用户
initial_admin_username: admin # 初始管理员用户名
initial_admin_password: password # 初始管理员密码
ask_timeout: 600    # 用于限制对话的最长时间

chatgpt_access_token: "你的access_token" # 需要从 ChatGPT 获取，见后文
chatgpt_paid: true # 是否为 ChatGPT Plus 用户

# 注意：如果你希望使用公共代理，或使用整合的 go-proxy-api，请保持注释；如果需要自定义，注意最后一定要有一个斜杠
# 在实际请求时，chatgpt_base_url 优先级为：config 内定义 > 环境变量 > revChatGPT 内置的公共代理
# chatgpt_base_url: http://公网ip或者docker网络ip:6060/chatgpt

log_dir: /app/logs # 日志存储位置，不要随意修改
console_log_level: INFO # 日志等级，设置为 DEBUG 能够获得更多信息

# 以下用于统计，如不清楚可保持默认
request_log_counter_time_window: 2592000 # 请求日志时间范围，默认为最近 30 天
request_log_counter_interval: 1800 # 请求日志统计粒度，默认为 30 分钟
ask_log_time_window: 2592000 # 对话日志时间范围，默认为最近 7 天
sync_conversations_regularly: yes # 是否定期（每隔12小时）从账号中同步一次对话
```

## 部署在不同服务器上

部署web页面的服务器无需解锁openai

依旧先创建一个文件夹
```
mkdir ChatGPT-Share
cd ChatGPT-Share
```

### 创建`docker-compose.yml`配置

```
version: "3"

services:
  chatgpt-share:
    image: ghcr.io/moeakwak/chatgpt-web-share:latest
    container_name: chatgpt-web-share
    restart: always
    network_mode: bridge
    ports:
      - 8080:80 # web 端口号
    volumes:
      - ./data:/data # 存放数据库文件以及统计数据
      - ./config.yaml:/app/backend/api/config/config.yaml # 后端配置文件
      - ./logs:/app/logs # 存放日志文件
```

在能够解锁openai的服务器上部署`go-chatgpt-api`

依旧先创建一个文件夹
```
mkdir go-chatgpt-api
cd go-chatgpt-api
```
### 创建`docker-compose.yml`配置

```
version: "3"

services:
  go-chatgpt-api:
    container_name: go-chatgpt-api
    image: linweiyuan/go-chatgpt-api
    ports:
      - 6060:8080
    environment:
      - GO_CHATGPT_API_PROXY=
    restart: unless-stopped
```
### 配置`config.yaml`

```
print_sql: false
host: "127.0.0.1"
port: 8000
data_dir: /data # <------ v0.3.0 以上新增
database_url: "sqlite+aiosqlite:////data/database.db" # 特别注意：这里有四个斜杠，代表着文件位于 /data 目录，使用的是绝对路径
run_migration: false # 是否在启动时运行数据库迁移，目前没有必要启用

jwt_secret: "你的 jwt secret" # 用于生成 jwt token，自行填写随机字符串
jwt_lifetime_seconds: 86400 # jwt token 过期时间
cookie_max_age: 86400 # cookie 过期时间
user_secret: "你的 user secret" # 用于生成用户密码，自行填写随机字符串

sync_conversations_on_startup: true # 是否在启动时同步同步 ChatGPT 对话，建议启用。启用后，将会自动将 ChatGPT 中新增的对话同步到数据库中，并把已经不在 ChatGPT 中的对话标记为无效
create_initial_admin_user: true # 是否创建初始管理员用户
initial_admin_username: admin # 初始管理员用户名
initial_admin_password: password # 初始管理员密码
ask_timeout: 600    # 用于限制对话的最长时间

chatgpt_access_token: "你的access_token" # 需要从 ChatGPT 获取，见后文
chatgpt_paid: true # 是否为 ChatGPT Plus 用户

# 注意：如果你希望使用公共代理，或使用整合的 go-proxy-api，请保持注释；如果需要自定义，注意最后一定要有一个斜杠
# 在实际请求时，chatgpt_base_url 优先级为：config 内定义 > 环境变量 > revChatGPT 内置的公共代理
chatgpt_base_url: http://公网ip或者docker网络ip:6060/

log_dir: /app/logs # 日志存储位置，不要随意修改
console_log_level: INFO # 日志等级，设置为 DEBUG 能够获得更多信息

# 以下用于统计，如不清楚可保持默认
request_log_counter_time_window: 2592000 # 请求日志时间范围，默认为最近 30 天
request_log_counter_interval: 1800 # 请求日志统计粒度，默认为 30 分钟
ask_log_time_window: 2592000 # 对话日志时间范围，默认为最近 7 天
sync_conversations_regularly: yes # 是否定期（每隔12小时）从账号中同步一次对话
```

注意上面的`chatgpt_base_url`后面填写你用于解锁openai的服务器http://ip:端口/chatgpt/


## 启动

启动

```
docker-compose up -d
```

停止

```
docker-compose stop
```

