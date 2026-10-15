# sh/ 脚本说明（README）

> 适用范围：本目录下 **`backup.sh` / `ddns.sh` / `ssh.sh` / `start.sh`** 四个脚本。
> `toolbox.sh`（综合工具箱，约 3,400 行）不在本文档范围内，使用方法见仓库根目录 `README.md`。
> 文档基于 2026-10-13 的 `main` 分支实测（文件行数 / 行为均已核对）。

---

## 目录

- [0. 总览](#0-总览)
- [1. start.sh —— 一键部署编排](#1-startsh--一键部署编排)
- [2. ddns.sh —— Cloudflare DDNS](#2-ddnsh--cloudflare-ddns)
- [3. ssh.sh —— SSH 配置与公钥管理](#3-sshsh--ssh-配置与公钥管理)
- [4. backup.sh —— Docker Compose 项目备份](#4-backupsh--docker-compose-项目备份)
- [5. 依赖与运行环境](#5-依赖与运行环境)
- [6. 典型组合用法](#6-典型组合用法)
- [7. 已知问题与注意事项](#7-已知问题与注意事项)

---

## 0. 总览

| 脚本        | 行数 | 作用                                            | 运行身份         | 是否依赖其他脚本/文件                              |
| ----------- | ---- | ----------------------------------------------- | ---------------- | -------------------------------------------------- |
| `start.sh`  | 432  | 部署编排入口：DDNS / 安装代理 / 改配置 / 装探针 | root 或可 `sudo` | 会**从远程下载** `ddns.sh` 与 `config/soga-*.conf` |
| `ddns.sh`   | 497  | 用 Cloudflare API 更新/创建 A / AAAA 记录       | 任意用户         | 仅需 `curl`                                        |
| `ssh.sh`    | 347  | 修改 `sshd_config`、维护 root 公钥              | **必须 root**    | 可选读 `ssh.env`                                   |
| `backup.sh` | 198  | 备份 docker compose 项目目录并打包              | 需 docker 权限   | 需 `rsync` / `docker`                              |

四个脚本共用同一套彩色日志风格（`[INFO] / [OK] / [WARN] / [ERROR]`），其中：

- `start.sh`、`ssh.sh` 用 `\033[3Xm` 双引号转义（写法为 `printf "%b"`）；
- `ddns.sh` 额外提供 `--mode color|plain|compact` 输出控制，**适合写日志/进 cron**。

---

## 1. `start.sh` —— 一键部署编排

面向「新装 VPS」的一站式脚本：把 DDNS、代理安装、配置改写、探针安装串成菜单。

### 用法

```bash
curl -L "https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/start.sh" -o start.sh
chmod +x start.sh
./start.sh -f <env文件路径或URL> -R <DNS前缀> -S <ss节点ID> -V <vmess节点ID> -C <选项> -U <哪吒UUID>
```

### 参数

| 参数             | 说明                                        | 默认      |
| ---------------- | ------------------------------------------- | --------- |
| `-f <path\|url>` | env 文件：本地路径 **或** `http(s)://` 地址 | `vps.env` |
| `-R <prefix>`    | DNS 记录前缀（拼成 `<prefix>.<domain1>`）   | 空        |
| `-S <id>`        | soga Shadowsocks 实例的 `node_id`           | 空        |
| `-V <id>`        | soga Vmess 实例的 `node_id`                 | 空        |
| `-C <0..6>`      | 执行项，不填则进入交互菜单                  | 交互      |
| `-U <uuid>`      | 哪吒探针的 `NZ_UUID`                        | 空        |
| `-h`             | 帮助                                        | —         |

### 交互菜单

| 选项 | 含义                                        |
| ---- | ------------------------------------------- |
| `1`  | 全部执行（DDNS → 装代理 → 改配置 → 装探针） |
| `2`  | 仅执行 DDNS                                 |
| `3`  | 仅安装代理（soga）                          |
| `4`  | 仅修改配置文件                              |
| `5`  | 仅安装哪吒探针                              |
| `6`  | 安装代理 + 修改配置文件（最常用）           |
| `0`  | 退出                                        |

### 前置动作

1. **`uzip` 环境检查**：优先用已有的 `uzip`；否则若系统有 `unzip` 就软链到 `/usr/local/bin/uzip`；都没有则自动装 `unzip`。
2. **包管理器探测**：按 `apt → yum → dnf → pacman → apk → zypper` 顺序自动识别。
3. **下载器探测**：有 `curl` 用 `curl -fsSL`，否则 `wget -qO`。

### env 文件读取

脚本**只解析形如 KEY=VALUE 的行**（`#` 开头跳过），并会剥掉值两端的 `"` `'`。读取以下键：

```
cf_key  cf_email  domain1  domain2
v2board_webapi_url  v2board_webapi_key
nezha_panel_ip  nezha_panel_port  nezha_panel_tls  nezha_agent_key
```

**文件查找逻辑**：

- `-f` 给的是 `http(s)://` → 下载并保存为 `vps.env`；
- `-f` 给的本地文件不存在 → **交互式询问 URL**（`read -r`）；
- `-f` 给的本地文件名 ≠ `vps.env` → 会 `cp -f` 复制成当前目录的 `vps.env`。

> ⚠️ 脚本第 245–254 行会**把 `cf_key` / `v2board_webapi_key` / `nezha_agent_key` 等明文打印到屏幕**。贴日志、贴 issue 前必须打码。

### 六个功能模块

**① `execute_ddns()`** — 从 raw 下载 `ddns.sh` 到临时文件后调用三次：

```bash
"$tmp" -k "$cf_key" -e "$cf_email" -d "$domain1" -r "$record_prefix.$domain1"      -t A    -p "false"
"$tmp" -k "$cf_key" -e "$cf_email" -d "$domain1" -r "$record_prefix-v6.$domain1"   -t AAAA -p "false"
"$tmp" -k "$cf_key" -e "$cf_email" -d "$domain2" -r "$record_prefix.$domain2"      -t A    -p "true"   # 仅当 domain2 非空
```

**② `install_proxy()`** — 架构探测（`amd64 / arm64 / arm`）→ 下载 `vaxilu/soga-cmd` 到 `/usr/bin/soga` → `soga update 2.13.4` → `soga new ss` / `soga new vmess`。

**③ `modify_config_files()`** — 下载 `config/soga-ss.conf`、`config/soga-vmess.conf` 覆盖到 `/etc/soga/{ss,vmess}/soga.conf`，再用 `sed` 写入 `node_id` / `webapi_url` / `webapi_key`，最后 `soga start` + `soga enable`。

**④ `install_nezha_agent()`** — 下载 `nezhahq/scripts` 的 `agent/install.sh`，以环境变量 `NZ_SERVER` / `NZ_TLS` / `NZ_CLIENT_SECRET` / `NZ_UUID` 执行。

### 注意

- 脚本头是 `set -euo pipefail`；`option 1`（全部执行）里每个模块都带 `|| true`，**单模块失败不会中断整轮**。
- 临时文件用 `mktemp` + `trap 'rm -f "$tmp"' RETURN` 清理。

---

## 2. `ddns.sh` —— Cloudflare DDNS

把本机公网 IP 同步到 Cloudflare 的 A / AAAA 记录，记录不存在时**自动创建**。

### 用法

```bash
./ddns.sh -k <api_token> -d <domain> -r <record> [选项]
```

### 参数

| 参数                           | 必填 | 说明                                                         | 默认    |
| ------------------------------ | ---- | ------------------------------------------------------------ | ------- |
| `-k <token>`                   | ✅    | Cloudflare **API Token**（走 `Authorization: Bearer`）；也可用环境变量 `cf_key` | —       |
| `-d <domain>`                  | ✅    | 主域名，如 `example.com`                                     | —       |
| `-r <record>`                  | ✅    | 完整记录名，如 `home.example.com`                            | —       |
| `-e <email>`                   | ❌    | **兼容保留**，Token 模式不需要邮箱，值已不使用               | 空      |
| `-t <A\|AAAA>`                 | ❌    | 记录类型                                                     | `A`     |
| `-p <true\|false>`             | ❌    | 是否开启 Cloudflare 橙云代理                                 | `false` |
| `--mode color\|plain\|compact` | ❌    | 输出模式                                                     | `color` |
| `--color` / `--no-color`       | ❌    | 强制彩色 / 关闭彩色                                          | —       |
| `-h`, `--help`                 | ❌    | 帮助                                                         | —       |

### 执行流程

1. 取公网 IP：`curl -6 -fsS ip.sb`（AAAA）或 `curl -4 -fsS ip.sb`（A）；
2. `GET /zones?name=<domain>` 取 Zone ID；
3. `GET /zones/<zone>/dns_records?type=&name=` 查现有记录；
4. 记录存在 → IP 有变化则 **`PUT` 更新**，无变化则跳过；记录不存在 → **`POST` 创建**；
5. 打印「执行结果」汇总块（状态 / 操作 / 新旧 IP / Zone ID / 起止时间）。

### 关于认证

- **只能填 API Token，不要填 Global API Key**（Global API Key 走的是 `X-Auth-Email` + `X-Auth-Key`，本脚本已改成 Bearer）。
- Token 权限：`Zone.DNS:Edit` + `Zone:Read` **两个都要**，Zone Resources 需覆盖目标域名。
- 该 Token 与 Caddy DNS-01 证书、ddns-go、飞牛内置 DDNS **可共用一个**（权限完全重合）。
- ⚠️ **环境变量回退在仓库版实际不生效**：源码第 28–29 行写的是 `cf_key=""` / `cf_email=""`，**先把变量清空**，随后的注释虽写着「未提供时回退到同名环境变量」，但代码并没有 `${cf_key:-}` 这层回退 ⇒ `export cf_key=...` 会被覆盖为空。**现状必须用 `-k` 传值**。（本地 v2 版才有真正的 env 回退，见 §7 第 13 条。）

### 输出模式

```bash
./ddns.sh -k "$TOKEN" -d example.com -r home.example.com --mode compact
# 成功 | 更新记录 | A | home.example.com | 1.2.3.4 -> 1.2.3.5
```

`compact` 模式只输出一行 `状态 | 操作 | 类型 | 记录名 | 旧IP -> 新IP`，**推荐写 cron 用**。

### cron 示例

```cron
*/2 * * * * /root/ddns.sh -k "TOKEN" -d "example.com" -r "home.example.com" -t A -p false --mode compact >> /root/ddns.log 2>&1
```

---

## 3. `ssh.sh` —— SSH 配置与公钥管理

改 `sshd_config` 的常用项 + 维护 `/root/.ssh/authorized_keys`，改完自动校验语法并重启服务。

### 用法

```bash
./ssh.sh -f ssh.env -P 2222 -R no -A no -U yes -K "ssh-ed25519 AAAA..." -C 1
```

**必须以 root 运行**（脚本开头即校验 `id -u`）。

### 参数

| 参数             | 说明                                             | 默认                        |
| ---------------- | ------------------------------------------------ | --------------------------- |
| `-f <path\|url>` | env 文件路径或 URL                               | `ssh.env`（不存在也不报错） |
| `-P <port>`      | `Port`                                           | `22`                        |
| `-R <yes\|no>`   | `PermitRootLogin`                                | `yes`                       |
| `-A <yes\|no>`   | `PasswordAuthentication`                         | `yes`                       |
| `-E <yes\|no>`   | `PermitEmptyPasswords`                           | `no`                        |
| `-M <n>`         | `MaxAuthTries`                                   | `3`                         |
| `-U <yes\|no>`   | `PubkeyAuthentication`                           | `yes`                       |
| `-K <公钥整行>`  | 直接指定公钥字符串                               | —                           |
| `-N <名字>`      | 从 env 读 `pubkey_<名字>` 变量作为公钥           | —                           |
| `-C <0\|1\|2>`   | 操作：`1` 改全部并重启 / `2` 仅加公钥 / `0` 退出 | 交互                        |
| `-h`             | 帮助                                             | —                           |

### 取值优先级

**命令行 > env 文件 > 内置默认**。

env 文件的键名对应关系：

```
ssh_port  ssh_permit_root_login  ssh_password_auth
ssh_permit_empty_passwords  ssh_max_auth_tries  ssh_pubkey_auth  pubkey_<名字>
```

`yes/no` 会被规范化：`1|y|yes|on|true` → `yes`，`0|n|no|off|false` → `no`。

### 关键行为

- **改配置前自动备份**：`cp -a sshd_config sshd_config.bak.<unix时间戳>`（同一次运行只在首次修改时备份一次）。
- **定向替换**：`sed -i "/^[#[:space:]]*<Key>[[:space:]]/Id"` 删除原有（含被注释的）同名项，再把新值追加到文件末尾 —— 这样**最后一条生效**，与 sshd 的解析规则一致。
- **公钥去重**：`grep -qxF` 命中则跳过，否则追加；会确保 `/root/.ssh` 为 `700`、`authorized_keys` 为 `600` 且属 `root:root`。
- **重启前先校验**：`sshd -t`，失败直接退出；重启优先 `systemctl restart sshd`，退而 `ssh.service`，再退而 `service`。

> ⚠️ **默认值偏宽松**（`PermitRootLogin yes` + `PasswordAuthentication yes`）。生产环境建议显式传 `-R prohibit-password -A no -U yes -K "<公钥>"`。

---

## 4. `backup.sh` —— Docker Compose 项目备份

把整个项目目录停服 → 复制 → 打包，产出带日期的压缩包。

### 用法

```bash
bash backup.sh -b /srv/docker/emby -f /mnt/backup -z tar.gz -d no -l /var/log/docker_backup.log
bash backup.sh -b /data/static -c no          # 纯目录备份，无 docker 操作
```

### 参数

| 参数           | 说明                           | 默认                   |
| -------------- | ------------------------------ | ---------------------- |
| `-b <路径>`    | **必填**，被备份的项目目录     | —                      |
| `-p <路径>`    | 临时目录                       | `/home/Backup/temp`    |
| `-f <路径>`    | 备份输出目录                   | `/home/Backup`         |
| `-z <fmt>`     | 压缩格式：`tar.gz` 或 `zip`    | `tar.gz`               |
| `-d <yes\|no>` | 成功后是否清理临时目录         | `yes`                  |
| `-l <路径>`    | 日志文件                       | `/home/log/Backup.log` |
| `-c <yes\|no>` | 是否按 docker compose 项目处理 | `yes`                  |

### 执行步骤

1. **校验**：`-b` 必填且目录存在；`-c` 只接受 `yes/no`。
2. **探测 compose 文件**：在目标目录里找 `docker-compose.yml/.yaml` 或 `compose.yml/.yaml`；**找不到就自动降级为非 compose 模式**（仅复制 + 压缩）。
3. `[1/4]` compose 模式：`cd <目标> && docker compose down`（**服务会短暂中断**）。
4. `[2/4] rsync -a --delete <目标>/ <临时/<项目名>>/`。
5. `[3/4]` compose 模式：`docker compose up -d`（**先恢复服务再压缩**，停机时间最短）。
6. `[4/4]` 压缩到 `<备份目录>/<YYYYMMDD> <项目名>.tar.gz`：
   - `zip`：有 `zip` 命令才用，否则**自动回退 tar.gz**；
   - `tar.gz`：有 `pigz` 用 `tar -I pigz`，否则 `tar -czf`；
   - 不认识的格式 → 直接按 tar.gz 处理。
7. **结果校验**：压缩失败或产出文件为空 → 报错退出，**保留临时目录**便于排查。
8. 成功且 `-d yes` → `rm -rf` 临时目录。

### 日志

`log()` 会**同时**打印到屏幕和追加进 `-l` 指定的日志文件（并自动 `mkdir -p` 其父目录）。`docker compose` / `rsync` / `tar` 的详细输出**只写日志文件**，不进屏幕。

### cron 示例

```cron
30 3 * * * /bin/bash /home/backup.sh -b /srv/docker/emby -f /mnt/backup -d yes -l /var/log/docker_backup.log
```

---

## 5. 依赖与运行环境

| 依赖                   | 谁需要                  | 说明                                             |
| ---------------------- | ----------------------- | ------------------------------------------------ |
| `bash` 4+              | 全部                    | `start.sh` 用了关联数组 `declare -A`             |
| `curl` 或 `wget`       | `start.sh` / `ddns.sh`  | `start.sh` 两者任一即可；`ddns.sh` **只用 curl** |
| `jq`                   | `ddns.sh`               | **可选**，缺失时回退到 `grep -Po` 解析 JSON      |
| `rsync`                | `backup.sh`             | 复制项目文件                                     |
| `docker` + compose     | `backup.sh`（`-c yes`） | 非 compose 模式不需要                            |
| `tar` / `pigz` / `zip` | `backup.sh`             | `pigz`、`zip` 均**可选**，缺失自动降级           |
| `openssh-server`       | `ssh.sh`                | 需要 `sshd -t` 与 systemd/service                |
| `sudo`                 | `start.sh` / `ssh.sh`   | 非 root 时用                                     |

---

## 6. 典型组合用法

### 6.1 新装 VPS 一把梭

```bash
# 1) 准备 env（建议放本机，chmod 600）
cat > /root/.config/vps/vps.env <<'EOF'
cf_key="cfut_xxxxxxxx"
cf_email=""
domain1="example.com"
domain2=""
v2board_webapi_url="https://panel.example.com"
v2board_webapi_key="xxxxxxxx"
nezha_panel_ip="nezha.example.com"
nezha_panel_port="443"
nezha_panel_tls="true"
nezha_agent_key="xxxxxxxx"
EOF
chmod 600 /root/.config/vps/vps.env

# 2) 执行（-C 6 = 装代理 + 改配置；-C 1 = 全部）
./start.sh -f /root/.config/vps/vps.env -R home -S 12 -V 13 -U <uuid> -C 6
```

### 6.2 DDNS 单独跑（cron）

见 [§2 cron 示例](#cron-示例)。

### 6.3 收紧 SSH 后仅用密钥登录

```bash
./ssh.sh -P 2222 -R prohibit-password -A no -E no -M 3 -U yes -K "ssh-ed25519 AAAA... me@pc" -C 1
```

### 6.4 每日备份

见 [§4 cron 示例](#cron-示例-1)。

---

## 7. 已知问题与注意事项

1. **仓库根 `README.md` 里的 ddns 用法已过期**：写的 `-k -u -z -h -l` 与当前脚本（`-k -d -r -t -p`）不符，且 `-h` 现在是 help ⇒ 照那份 README 敲会报「无效选项」，请以本文档为准。
2. **根 README 的 `start.sh` 示例参数也过期**：示例里写 `-K 哪吒key`，但脚本实际参数是 `-U <UUID>`。
3. **`config/env_vps.txt` 模板与 `start.sh` 不匹配**：模板里用的是 `1_domain` / `2_domain`，而脚本读的是 **`domain1` / `domain2`**；模板还缺 `nezha_panel_tls`、`nezha_agent_key`。直接拿模板用会**读不到域名**。
4. **`ddns.sh` 失败时可能看不到「执行结果」汇总**：脚本用 `trap on_error ERR` 兜底打印，但 `get_public_ip` / `get_zone_id` / `update_record` 等分支是先 `set_failure` 再 **`exit 1`** —— 而 ERR trap **只响应"命令返回非零"，不响应 `exit`** ⇒ 这些路径会直接退出、不打印汇总。排查时看 `[ERROR]` 行而不是汇总块。
5. **`ddns.sh` 用 `PUT` 全量替换记录**：会清掉原有的 `ttl` / `comment` 等字段（不是 `PATCH` 合并）。
6. **`-p` 默认 `false`，且 `start.sh` 对 A / AAAA 两条显式传 `-p "false"`** ⇒ **每轮 cron 都会把这两条写回灰云**；在 Cloudflare 面板手工开的橙云会被静默覆盖。要用橙云得改 `start.sh` 那两行，或改用飞牛内置 DDNS 等其它方案。
7. **橙云有端口白名单**：Cloudflare 代理只放行 HTTP `80/8080/8880/2052/2082/2086/2095` + HTTPS `443/2053/2083/2087/2096/8443`。管理端口（如 5666/5667）**不在名单里，开了橙云必访问失败**。
8. **`start.sh` 会把凭据打印到屏幕**（第 245–254 行）⇒ 日志/截图务必打码。
9. **`start.sh -f` 的文件名不是 `vps.env` 时会 `cp -f` 复制一份到当前目录**，等于凭空多一份明文，且权限与源文件无关。
10. **`backup.sh` 的 `docker compose down` 会让服务中断**；`rsync --delete` 会删除临时目录里目标目录已不存在的文件 —— 这是刻意的"镜像式"备份，别把临时目录当存档用。
11. **`ssh.sh` 默认放行 root 密码登录**，仅适合一次性初始化；用完请立刻用 §6.3 的方式收紧。
12. **凭据建议一台机器一个 Token**，并统一放本机 `600` 权限文件，不要提交进仓库、不要放 gist（GitHub Secret Scanning 会扫 gist 并通知 Cloudflare 自动吊销）。
13. <span>**仓库 `sh/ddns.sh` 与本地 v2 版只差两行，但这两行影响行为**</span>：仓库版是 `cf_key=""` / `cf_email=""`（**注释说支持 env 回退，代码没有**）；本地 `ddns-token-20261012-v2.sh` 是 `cf_key="${cf_key:-}"` / `cf_email="${cf_email:-}"`（**真正支持 env 回退**）。除此之外两份文件逐字节一致（均 497 行；仓库版 md5 `74e14eaafb1cdda1cb2dbfa01ca30305`，本地 v2 md5 `9c0589be8b682136581bf3df41e4e815`）。若依赖 `export cf_key=` 传凭据，需要把这两行补上。

---

*文档日期：2026-10-13 · 对应 `main` 分支：`backup.sh` 198 行 / `ddns.sh` 497 行 / `ssh.sh` 347 行 / `start.sh` 432 行*
