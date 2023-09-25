ChatGPT Web Share 0.4.0-alpha5

[作者仓库](https://github.com/moeakwak/chatgpt-web-share)

## 0.4.0-alpha5

首先依旧是创建一个文件夹

```
mkdir ChatGPT-Share
cd ChatGPT-Share
```
在这个文件夹内创建`docker-compose.yml`文件

```
touch docker-compose.yml
```

`docker-compose.yml`配置

```
version: "3"

services:
  chatgpt-web-share:
    image: ghcr.io/moeakwak/chatgpt-web-share:0.4.0-alpha5
    container_name: cws #任意
    restart: always
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

```
touch config.yaml
```

编辑`config.yaml`配置

```
openai_web:
  enabled: true
  is_plus_account: true
  chatgpt_base_url: https://ai.fakeopen.com/api/
  proxy:
  common_timeout: 10
  ask_timeout: 600
  enabled_models:
  - gpt_3_5
  - gpt_3_5_mobile
  - gpt_4
  - gpt_4_code_interpreter
  - gpt_4_plugins
  - gpt_4_mobile
  model_code_mapping:
    gpt_3_5: text-davinci-002-render-sha
    gpt_3_5_mobile: text-davinci-002-render-sha-mobile
    gpt_4: gpt-4
    gpt_4_mobile: gpt-4-mobile
    gpt_4_browsing: gpt-4-browsing
    gpt_4_plugins: gpt-4-plugins
    gpt_4_code_interpreter: gpt-4-code-interpreter
openai_api:
  enabled: true
  openai_base_url: https://api.openai.com/v1/
  proxy:
  connect_timeout: 10
  read_timeout: 20
  enabled_models:
  - gpt_3_5
  - gpt_4
  model_code_mapping:
    gpt_3_5: gpt-3.5-turbo
    gpt_4: gpt-4
common:
  sync_conversations_on_startup: true
  sync_conversations_regularly: false
  print_sql: false
  create_initial_admin_user: true
  initial_admin_user_username: admin
  initial_admin_user_password: adminadmin
http:
  host: 127.0.0.1
  port: 8000
  cors_allow_origins:
  - http://localhost
  - http://127.0.0.1
data:
  data_dir: ./data
  database_url: sqlite+aiosqlite:///data/database.db
  mongodb_url: mongodb://chatgpt:123456@mongo:27017
  run_migration: false
auth:
  jwt_secret: #随机生成
  jwt_lifetime_seconds: 86400
  cookie_max_age: 86400
  cookie_name: user_auth
  user_secret: #随机生成
stats:
  ask_stats_ttl: 7776000
  request_stats_ttl: 2592000
  request_stats_filter_keywords:
  - /status
log:
  console_log_level: DEBUG

```

  再创建文件`credentials.yaml`

```
touch credentials.yaml
```

 编辑 `credentials.yaml`配置

```
openai_web_access_token: 
  #在第二行空两格然后填入你的token
openai_api_key: #空一格填入你的token
```

记得删除不必要的注释



然后回到存放`docker-compose.yml`文件的目录

然后启动容器

```
docker-compose up -d
```

然后通过

`http://ip:port`来访问

建议自行部署反代

