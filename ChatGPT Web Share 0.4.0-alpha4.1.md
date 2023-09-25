ChatGPT Web Share 0.4.0-alpha4.1

## 0.4.0-alpha4.1

首先依旧是创建一个文件夹

```
mkdir ChatGPT-Share
cd ChatGPT-Share
```
在这个文件夹内创建`docker-compose.yml`文件

`docker-compose.yml`配置

```
version: "3"

services:
  chatgpt-web-share:
    image: ghcr.io/moeakwak/chatgpt-web-share:0.4.0-alpha4.1
    container_name: cws #任意
    restart: unless-stopped
    ports:
      - 8088:80 #任意
    volumes:
      - ./data:/app/backend/data
    environment:
      - TZ=Asia/Shanghai
      - CWS_CONFIG_DIR=/app/backend/data/config
    depends_on:
      - mongo
    
  mongo:
    image: mongo:6.0
    restart: always
    ports:
      - 27017:27017
    volumes:
      - ./mongo_data:/data/db
    environment:
      MONGO_INITDB_DATABASE: chatgpt #任意
      MONGO_INITDB_ROOT_USERNAME: chatgpt #任意
      MONGO_INITDB_ROOT_PASSWORD: 123456 #任意

```

在此文件夹也就是`./ChatGPT-Share`中创建文件夹`./ChatGPT-Share/data/config`

进入`config`文件夹

```
cd ./ChatGPT-Share/data/config
```

创建`config.yaml`文件

`config.yaml`配置

```
common:
  print_sql: false
  create_initial_admin_user: true
  initial_admin_user_username: admin
  initial_admin_user_password: password
  sync_conversations_on_startup: true
  sync_conversations_regularly: false
http:
  host: 127.0.0.1
  port: 8000 #任意
  cors_allow_origins:
  - http://localhost
  - http://127.0.0.1
data:
  data_dir: ./data
  database_url: sqlite+aiosqlite:///data/database.db
  mongodb_url: mongodb://chatgpt:123456@mongo:27017 #跟上文对应
  run_migration: false
auth:
  jwt_secret: XXX #具体干嘛的我也不知道,如果你知道请告诉我,建议随机生成
  jwt_lifetime_seconds: 86400
  cookie_max_age: 86400
  cookie_name: user_auth
  user_secret: XXX #具体干嘛的我也不知道,如果你知道请告诉我,建议随机生成
revchatgpt:
  is_plus_account: false
  chatgpt_base_url: http://ip:端口/chatgpt/backend-api/ #你的反代地址"go chatgpt"
  ask_timeout: 600
api:
  openai_base_url: https://api.openai.com/v1/
  connect_timeout: 10
  read_timeout: 10
log:
  console_log_level: INFO
stats:
  request_counter_time_window: 2592000
  request_counts_interval: 1800
  ask_log_time_window: 604800
  ```

  再创建文件`credentials.yaml`

  `credentials.yaml`配置

```
chatgpt_access_token: ""
openai_api_key: " "
```

然后直接启动就好了