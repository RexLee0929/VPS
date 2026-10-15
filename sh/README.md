# sh/ 脚本说明（README）

> **规范版本：UNIFIED v2**（公共区段 v2.0 + 两段式参数解析）
> 适用范围：本目录下 **`start.sh` / `ddns.sh` / `env.sh` / `ssh.sh` / `proxy.sh` / `nezha.sh`** 六个脚本。
> 文档基于 2026-10-15 实测版本编写（行数 / 行为 / 校验和均已核对），对应本地 `sh/` 目录的 UNIFIED v2 版本——**这六份文件用于整体覆盖仓库 `main/sh/` 的旧版脚本**（旧版为单体 `start.sh` 432 行 + `ddns.sh` 497 行等，README 用法已过期，请以本文档为准）。

| 脚本       | 版本   | 行数 | md5                                |
| ---------- | ------ | ---- | ---------------------------------- |
| `start.sh` | v2.1.0 | 757  | `78b0538cce3608464538dc0783dbf042` |
| `ddns.sh`  | v2.0.0 | 642  | `9dd8e5f09707fb4925ed6f45d41a974a` |
| `ssh.sh`   | v2.0.0 | 568  | `15d6888dda2141204fcc475ded7e5bf8` |
| `proxy.sh` | v2.1.0 | 526  | `ae64684cd742cb907001fde4316fd712` |
| `env.sh`   | v2.0.0 | 518  | `8f35dc0ddb064455058ab692662a8661` |
| `nezha.sh` | v2.1.0 | 488  | `84c5cbb46c7f7b038da900ab55003249` |

---

## 目录

- [0. 总览与统一规范](#0-总览与统一规范)
- [1. start.sh —— 一键部署编排入口](#1-startsh--一键部署编排入口)
- [2. ddns.sh —— Cloudflare DDNS](#2-ddnssh--cloudflare-ddns)
- [3. env.sh —— 从 1Password 拉取 env 文件](#3-envsh--从-1password-拉取-env-文件)
- [4. ssh.sh —— SSH 配置与公钥管理](#4-sshsh--ssh-配置与公钥管理)
- [5. proxy.sh —— soga 代理安装与配置](#5-proxysh--soga-代理安装与配置)
- [6. nezha.sh —— 哪吒探针 Agent 安装](#6-nezhash--哪吒探针-agent-安装)
- [7. 公共区段 v2.0（六脚本一致）](#7-公共区段-v20六脚本一致)
- [8. 依赖与运行环境](#8-依赖与运行环境)
- [9. 典型组合用法](#9-典型组合用法)
- [10. 已知问题与注意事项](#10-已知问题与注意事项)

---

## 0. 总览与统一规范

### 0.1 六个脚本的分工

| 脚本       | 作用                                                         | 运行身份         | 依赖                                                         |
| ---------- | ------------------------------------------------------------ | ---------------- | ------------------------------------------------------------ |
| `start.sh` | **编排入口**：加载 env → 解析配置 → 选执行项 → 按需委托子脚本 | root 或可 `sudo` | 委托 `ddns.sh` / `proxy.sh` / `nezha.sh`（本地优先，缺失自动从仓库下载） |
| `ddns.sh`  | 把本机公网 IP 同步成 Cloudflare A / AAAA 记录                | 任意用户         | 仅需 `curl`（`jq` 可选）                                     |
| `env.sh`   | 从 1Password 拉取完整 env 文件到本地                         | 任意用户         | `op`（1Password CLI）≥ 2.18.0                                |
| `ssh.sh`   | 改 `sshd_config` 常用项 + 维护 root 公钥                     | **必须 root**    | `sshd` / systemd 或 service                                  |
| `proxy.sh` | soga 代理安装 / 配置文件修改（从 `start.sh` 拆出）           | root 或可 `sudo` | `curl` 或 `wget`                                             |
| `nezha.sh` | 哪吒探针 Agent 安装（从 `start.sh` 拆出）                    | root 或可 `sudo` | `curl`/`wget` + `unzip`（缺失自动装）                        |

### 0.2 UNIFIED v2 统一规范（全部脚本通用）

1. **长选项是唯一权威接口**：`--key value` / `--key=value` / `-k value` / `-kvalue` 四种写法都认。
   短选项仅为兼容保留，**且跨脚本含义不同**（如 `-t` 在 `env.sh` 是 token、在 `ddns.sh` 是记录类型；`-R` 在 `ssh.sh` 是 root 登录、在 `start.sh` 是 DNS 前缀）⇒ **串联执行一律用长选项**。
2. **取值优先级**：`命令行 > VPS_* 环境变量 > env 文件 > 内置默认 >（交互询问 / 报错）`。
   每个脚本的参数摘要都会用 `kv3` 标注每个值的**来源**。
3. **缺失参数一次性列全**：缺几项列几项，并给出可复制的补全方式，不是缺一个报一个。
4. **通用开关**（所有脚本都有）：`--dry-run`（只打印不落盘）、`--yes`（非交互）、`--no-color` / `--color`、`--verbose`、`--help` / `-h`、`--version`。
5. **敏感值一律脱敏**：屏幕只显示前 4 位 + 后 4 位 + 长度（≤8 字符显示 `********`），日志可安全贴出。
6. **不接受位置参数**：全部用选项传参，误给位置参数直接报错。
7. **`set -uo pipefail`**（刻意不用 `-e`），`IFS=$'\n\t'`。

### 0.3 脚本间关系

```
                    ┌──────────────┐
                    │  env.sh     │  从 1Password 拉取 → vps.env（默认输出名）
                    └──────┬───────┘
                           ↓ 供下面所有脚本读取
┌──────────────┐   choice 3/4/6   ┌──────────────┐
│  start.sh    │────────────────→│  proxy.sh    │  soga 安装 / 配置
│ （编排入口）  │                  └──────────────┘
│              │   choice 5       ┌──────────────┐
│              │────────────────→│  nezha.sh    │  哪吒探针
└──────┬───────┘                  └──────────────┘
       │ choice 1/2（DDNS）
       ↓
┌──────────────┐
│  ddns.sh     │  Cloudflare A / AAAA
└──────────────┘

ssh.sh 独立运行（改 sshd_config / 加公钥），不与 start.sh 联动
```

- `start.sh` 委托子脚本时用**长选项同名透传**；子脚本本地优先（脚本目录 → `./` → `/usr/local/bin`），找不到则从仓库 raw 下载，且会校验 `UNIFIED v2` 标记，旧版会被强制替换成最新版。
- `start.sh` 调 `ddns.sh` 时有 **v1 回退**：检测到旧版（无 `UNIFIED v2` 标记）自动切回旧短选项，可分批更新。

---

## 1. `start.sh` —— 一键部署编排入口

面向「新装 VPS」的一站式脚本：加载 env → 解析配置 → 交互/传参选执行项 → 按需委托子脚本。

### 1.1 用法

```bash
curl -L "https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/start.sh" -o start.sh
chmod +x start.sh
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6
```

### 1.2 执行项（`--choice` / `-C`）

| 选项 | 含义                                        | 委托                        |
| ---- | ------------------------------------------- | --------------------------- |
| `1`  | 全部执行（DDNS → 装代理 → 改配置 → 装探针） | 全部                        |
| `2`  | 仅 DDNS                                     | `ddns.sh`                   |
| `3`  | 仅安装代理（soga）                          | `proxy.sh --action=install` |
| `4`  | 仅修改配置文件                              | `proxy.sh --action=config`  |
| `5`  | 仅安装哪吒探针                              | `nezha.sh`                  |
| `6`  | 安装代理 + 修改配置（**最常用**）           | `proxy.sh --action=both`    |
| `0`  | 退出                                        | —                           |

不给 `--choice` 时：交互终端进菜单；**非交互（无 TTY）直接 exit 2**。

### 1.3 参数

| 长选项                  | 短选项 | 说明                                 | 默认           |
| ----------------------- | ------ | ------------------------------------ | -------------- |
| `--env <文件\|URL>`     | `-f`   | env 文件路径或 `http(s)://` 地址     | `vps.env`      |
| `--prefix <前缀>`       | `-R`   | DNS 记录前缀（拼成 `<前缀>.<域名>`） | 空（按根域名） |
| `--ss-id <id>`          | `-S`   | Shadowsocks 节点 ID                  | 空             |
| `--vmess-id <id>`       | `-V`   | Vmess 节点 ID                        | 空             |
| `--choice <0-6>`        | `-C`   | 执行项                               | 交互           |
| `--nz-uuid <uuid>`      | `-U`   | 哪吒 Agent UUID（不给由面板分配）    | 空             |
| `--soga-version <版本>` | —      | soga 版本，透传 `proxy.sh`           | `2.13.4`       |
| `--proxy-script <路径>` | —      | 指定 `proxy.sh` 路径                 | 自动查找/下载  |
| `--nezha-script <路径>` | —      | 指定 `nezha.sh` 路径                 | 自动查找/下载  |
| `--ddns-script <路径>`  | —      | 指定 `ddns.sh` 路径                  | 自动查找/下载  |
| `--save-env <路径>`     | —      | 把最终配置写回 env 文件（权限 600）  | 不写           |
| `--force`               | —      | 参数缺失时**跳过对应步骤**而不是退出 | 关             |

**env 缺失时的手动补参**（优先级最高，也可用对应 `VPS_*` 环境变量）：

```
--cf-key  --cf-email  --domain1  --domain2
--webapi-url  --webapi-key
--nezha-ip  --nezha-port  --nezha-tls  --nezha-key
```

### 1.4 env 文件

只解析 `KEY=VALUE` 行（`#` 注释与空行跳过，自动剥掉值两端的 `"` `'`）。读取的键：

```
cf_key  cf_email  domain1  domain2  record_prefix
v2board_webapi_url  v2board_webapi_key
nezha_panel_ip  nezha_panel_port  nezha_panel_tls  nezha_agent_key
```

查找逻辑：URL → 下载到当前目录 `vps.env`；本地路径存在 → 直接加载（**不再复制**）；找不到 → 进入手动传参模式（交互终端逐项询问，非交互一次列全后 exit 2）。

对应环境变量：`VPS_CF_KEY` `VPS_CF_EMAIL` `VPS_DOMAIN1` `VPS_DOMAIN2` `VPS_PREFIX` `VPS_SS_ID` `VPS_VMESS_ID` `VPS_WEBAPI_URL` `VPS_WEBAPI_KEY` `VPS_SOGA_VERSION` `VPS_NEZHA_IP` `VPS_NEZHA_PORT` `VPS_NEZHA_TLS` `VPS_NEZHA_KEY` `VPS_CHOICE` `VPS_NZ_UUID` `VPS_ENV`。

### 1.5 执行流程（5 段式）

1. **1/5 加载 env 文件**（缺失不退出，转手动模式）
2. **2/5 配置解析结果**（每项标注来源，敏感值脱敏）
3. **3/5 选择执行项**（交互菜单或 `--choice`）
4. **4/5 参数完整性检查**（只检查本次 choice 需要的项；缺项交互询问或一次列全；`--force` 可跳过）
5. **5/5 执行**（`--dry-run` 全程只打印）

### 1.6 DDNS 行为（choice 1/2）

需要 `cf_key` + `domain1`。对每个域名跑一次 `ddns.sh`：

| 记录                                      | 类型 | 橙云    |
| ----------------------------------------- | ---- | ------- |
| `<prefix>.<domain1>`                      | A    | `false` |
| `<prefix>-v6.<domain1>`                   | AAAA | `false` |
| `<prefix>.<domain2>`（仅 domain2 非空时） | A    | `true`  |

不给 `--prefix` 时按根域名处理并告警。

### 1.7 与旧版（v1）的差异

- **不再打印明文凭据**：v2 摘要全部走 `mask()` 脱敏（旧版 245–254 行会把 `cf_key` / `webapi_key` / `nezha_agent_key` 明文打屏）。
- 代理 / 探针逻辑拆去 `proxy.sh` / `nezha.sh`，`start.sh` 只做编排。
- 本地 env 文件不再 `cp -f` 复制成 `vps.env`（少一份明文副本）。

---

## 2. `ddns.sh` —— Cloudflare DDNS

把本机公网 IP 同步到 Cloudflare，记录不存在时**自动创建**，IP 无变化则跳过。

### 2.1 用法

```bash
./ddns.sh --domain=example.com --prefix=home
./ddns.sh --domain=example.com --record=home.example.com --type=AAAA --proxy=false
```

### 2.2 参数

| 长选项                           | 短选项 | 必填 | 说明                                             | 默认                                  |
| -------------------------------- | ------ | ---- | ------------------------------------------------ | ------------------------------------- |
| `--key <token>`                  | `-k`   | ✅    | Cloudflare **API Token**（Bearer 认证）          | 也可 `VPS_CF_KEY` / env 文件 `cf_key` |
| `--domain <域名>`                | `-d`   | ✅    | 主域名，如 `example.com`                         | 也可 `VPS_DDNS_DOMAIN`                |
| `--record <记录名>`              | `-r`   | ⬜    | 完整记录名，如 `home.example.com`                | 也可 `VPS_DDNS_RECORD`                |
| `--prefix <前缀>`                | —      | ⬜    | 前缀，与 `--domain` 组合                         | 也可 `VPS_DDNS_PREFIX`                |
| `--type <A\|AAAA>`               | `-t`   | ❌    | 记录类型                                         | `A`                                   |
| `--proxy <true\|false>`          | `-p`   | ❌    | 是否开 CF 橙云代理                               | `false`                               |
| `--email <邮箱>`                 | `-e`   | ❌    | **兼容保留**，Token 模式不使用（给了会校验格式） | 空                                    |
| `--mode <color\|plain\|compact>` | —      | ❌    | 输出模式                                         | 自动（TTY→color，否则 plain）         |

记录名推导：`--record` > `--prefix` + `--domain` > `--domain`（根域名，会告警）。

### 2.3 执行流程

1. 取公网 IP：依次尝试 `ip.sb` / `icanhazip.com` / `ifconfig.me/ip`（A 用 `curl -4`，AAAA 用 `curl -6`），并做格式校验；
2. `GET /zones?name=<domain>` 取 Zone ID；
3. `GET /zones/<zone>/dns_records?type=&name=` 查现有记录；
4. 记录存在 → IP 有变化则 **`PUT` 更新**，无变化跳过；不存在 → **`POST` 创建**；
5. 打印「执行结果」汇总块。

### 2.4 关于认证

- **只能填 API Token，不要填 Global API Key**（本脚本走 `Authorization: Bearer`）。
- Token 权限：`Zone.DNS:Edit` + `Zone:Read` **两个都要**，Zone Resources 覆盖目标域名。
- 该 Token 与 Caddy DNS-01 证书、ddns-go、飞牛内置 DDNS **可共用一个**（权限完全重合）。
- v2 起 `VPS_CF_KEY` 环境变量与 env 文件 `cf_key` 键的**回退真正生效**（旧仓库版是把变量硬清空，必须 `-k` 传值）。

### 2.5 输出模式与 cron

```bash
./ddns.sh --key "$TOKEN" --domain=example.com --prefix=home --mode compact
# 成功|更新记录|A|home.example.com|1.2.3.4 -> 1.2.3.5
```

`compact` 只输出一行，**推荐写 cron 用**：

```cron
*/2 * * * * /root/sh/ddns.sh --key "TOKEN" --domain "example.com" --prefix "home" --type A --proxy false --mode compact >> /root/ddns.log 2>&1
```

---

## 3. `env.sh` —— 从 1Password 拉取 env 文件

把 1Password 里「一条安全笔记 = 完整 env」拉到本机，**默认输出 `vps.env`**（与 `start.sh` 默认读取值一致，拉完直接跑 `start.sh`）。

### 3.1 用法

```bash
./env.sh --token=ops_xxxx --vault=Infra --item=vps-env
./env.sh --token-file=/root/.config/op/token --ref=op://Infra/vps-env/notesPlain
./env.sh --vault=Infra --item=vps-env --dry-run
```

### 3.2 参数

| 长选项                | 短选项 | 说明                                         | 默认                                              |
| --------------------- | ------ | -------------------------------------------- | ------------------------------------------------- |
| `--token <token>`     | `-t`   | Service Account token（必填，`ops_` 开头）   | 也可 `VPS_OP_TOKEN` / `$OP_SERVICE_ACCOUNT_TOKEN` |
| `--token-file <文件>` | `-T`   | 从文件读 token（首行，自动去换行）           | —                                                 |
| `--ref <op://…>`      | `-r`   | 完整引用 `<库>/<条目>/<字段>`                | 也可 `VPS_OP_REF`                                 |
| `--vault <库>`        | `-v`   | 保管库名（不给 `--ref` 时必填）              | 也可 `VPS_OP_VAULT`                               |
| `--item <条目>`       | `-i`   | 条目名（不给 `--ref` 时必填）                | 也可 `VPS_OP_ITEM`                                |
| `--field <字段>`      | `-F`   | 字段名，安全笔记正文 = `notesPlain`          | `notesPlain`                                      |
| `--out <文件>`        | `-o`   | 输出文件                                     | `vps.env`                                         |
| `--list-keys`         | —      | **只读**：列出已有 env 文件的 KEY 名，不拉取 | —                                                 |

token 优先级：`-t` > `--token-file` > `$OP_SERVICE_ACCOUNT_TOKEN`。

### 3.3 行为要点

- 检测不到 `op` 会打印官方一行安装法；版本 < 2 直接退出，< 2.18.0 告警（Service Account 需要 ≥ 2.18.0）。
- token 不是 `ops_` 开头会告警（可能是个人账号凭据）。
- 落盘前自动备份 `vps.env.bak.<时间戳>`；覆盖需确认（`--yes` 跳过）；写入后 `chmod 600`。
- **全程不打印 token、不打印任何值**，结果校验只列 KEY 名，并检查 `start.sh` 需要的 10 个核心键（`cf_key` / `cf_email` / `domain1` / `domain2` / `v2board_webapi_url` / `v2board_webapi_key` / `nezha_panel_ip` / `nezha_panel_port` / `nezha_panel_tls` / `nezha_agent_key`），缺哪些会列出。
- `op read` 失败的三种常见原因会直接给出：引用写错（大小写敏感）、SA 未授权该保管库、token 过期/被撤销。

> ⚠️ `-t "ops_..."` 会进 shell history，介意就用 `--token-file`。

---

## 4. `ssh.sh` —— SSH 配置与公钥管理

改 `sshd_config` 常用项 + 维护 `/root/.ssh/authorized_keys`，改完自动校验语法并重启服务。**必须以 root 运行**（`--dry-run` 除外）。

### 4.1 用法

```bash
./ssh.sh --port=2222 --root-login=no --password-auth=no --pubkey="$(cat ~/.ssh/id_ed25519.pub)" --choice=1
./ssh.sh --env=ssh.env --choice=2          # 仅加公钥
./ssh.sh --port=2222 --choice=1 --skip-restart --dry-run
```

### 4.2 参数

| 长选项                        | 短选项 | 说明                                       | 默认                      |
| ----------------------------- | ------ | ------------------------------------------ | ------------------------- |
| `--env <文件\|URL>`           | `-f`   | env 文件路径或 URL                         | `ssh.env`（不存在不报错） |
| `--port <端口>`               | `-P`   | `Port`（1-65535）                          | `22`                      |
| `--root-login <yes\|no>`      | `-R`   | `PermitRootLogin`                          | `yes`                     |
| `--password-auth <yes\|no>`   | `-A`   | `PasswordAuthentication`                   | `yes`                     |
| `--empty-passwords <yes\|no>` | `-E`   | `PermitEmptyPasswords`                     | `no`                      |
| `--max-auth-tries <n>`        | `-M`   | `MaxAuthTries`                             | `3`                       |
| `--pubkey-auth <yes\|no>`     | `-U`   | `PubkeyAuthentication`                     | `yes`                     |
| `--pubkey <公钥整行>`         | `-K`   | 直接给公钥字符串                           | —                         |
| `--pubkey-file <文件>`        | —      | 从文件读公钥（取首行）                     | —                         |
| `--pubkey-name <名字>`        | `-N`   | 从 env 读 `pubkey_<名字>`                  | —                         |
| `--config <路径>`             | —      | `sshd_config` 路径                         | `/etc/ssh/sshd_config`    |
| `--choice <0\|1\|2>`          | `-C`   | `1` 改全部并重启 / `2` 仅加公钥 / `0` 退出 | 交互                      |
| `--skip-restart`              | —      | 不重启 SSH 服务（配合 `--choice=1`）       | 关                        |

env 文件键（默认 `ssh.env`）：`ssh_port` `ssh_permit_root_login` `ssh_password_auth` `ssh_permit_empty_passwords` `ssh_max_auth_tries` `ssh_pubkey_auth` `ssh_choice` `pubkey_<名字>`。
环境变量：`VPS_SSH_ENV` `VPS_SSH_PORT` `VPS_SSH_ROOT_LOGIN` `VPS_SSH_PASSWORD_AUTH` `VPS_SSH_EMPTY_PASSWORDS` `VPS_SSH_MAX_AUTH_TRIES` `VPS_SSH_PUBKEY_AUTH` `VPS_SSH_PUBKEY` `VPS_SSH_CONFIG` `VPS_SSH_CHOICE`。

公钥来源优先级：`--pubkey` > `--pubkey-file` > `--pubkey-name`（env） > 交互。

### 4.3 关键行为

- **改前自动备份**：首次修改时 `cp -a sshd_config sshd_config.bak.<时间戳>`。
- **定向替换**：`sed` 删掉原有（含被注释的）同名项，新值追加到文件末尾——与 sshd「最后一条生效」的解析规则一致。
- **公钥去重**：`grep -qxF` 命中则跳过；确保 `/root/.ssh` 为 `700`、`authorized_keys` 为 `600` 且属 `root:root`。
- **重启前先校验**：`sshd -t`，失败直接退出不重启；重启优先 `systemctl restart sshd`，退 `ssh`，再退 `service`。

> ⚠️ **默认值偏宽松**（root 登录 + 密码认证全开），仅适合一次性初始化。生产建议：
> `./ssh.sh --root-login=no --password-auth=no --pubkey-file=~/.ssh/id_ed25519.pub --choice=1`
> ⚠️ v2 起 `--root-login` **只接受 `yes` / `no`**（`prohibit-password` 等值会报 exit 2）；要「仅密钥登录」用 `--root-login=no --password-auth=no` 组合。
> ⚠️ **改端口前先确认新端口已在防火墙放行**，否则可能把自己锁在门外。

---

## 5. `proxy.sh` —— soga 代理安装与配置

从 `start.sh` v2.1 拆出（choice 3/4/6 委托本脚本），也可单独运行。

### 5.1 用法

```bash
./proxy.sh --action=install
./proxy.sh --action=install --soga-version=2.14.0
./proxy.sh --action=config --ss-id=3 --vmess-id=4 --webapi-url=https://a --webapi-key=K
./proxy.sh --env=vps.env --dry-run
```

### 5.2 参数

| 长选项                             | 短选项 | 说明                                    | 默认                                          |
| ---------------------------------- | ------ | --------------------------------------- | --------------------------------------------- |
| `--action <install\|config\|both>` | `-a`   | 只装 / 只配 / 装+配                     | `both`                                        |
| `--soga-version <版本>`            | `-s`   | soga 版本（格式 `x.y.z`）               | `2.13.4`                                      |
| `--arch <amd64\|arm64\|arm>`       | —      | 目标架构                                | 自动检测                                      |
| `--ss-id <id>`                     | `-S`   | Shadowsocks 节点 ID（config/both 必填） | 也可 `VPS_SS_ID`                              |
| `--vmess-id <id>`                  | `-V`   | Vmess 节点 ID（config/both 必填）       | 也可 `VPS_VMESS_ID`                           |
| `--webapi-url <url>`               | —      | v2board webapi 地址（config/both 必填） | `VPS_WEBAPI_URL` / env `v2board_webapi_url`   |
| `--webapi-key <key>`               | —      | v2board webapi key（config/both 必填）  | `VPS_WEBAPI_KEY` / env `v2board_webapi_key`   |
| `--env <文件>`                     | `-f`   | env 文件路径                            | `vps.env`（存在才加载；指定了却不存在则报错） |
| `--no-restart`                     | —      | 配置写入后不启动 / 不启用实例           | 关                                            |

### 5.3 两条硬规则

1. **soga 默认 2.13.4**，要换版本用 `--soga-version`。
2. **`--action=config / both` 的四个对接参数必须显式传入**，空白（含纯空格）一律报错 **exit 2**，绝不拿空值写配置。只想安装用 `--action=install`。

### 5.4 执行细节

- **install**：下载 `vaxilu/soga-cmd` 最新 release 到 `/usr/bin/soga` → `soga update <版本>` → `soga new ss` / `soga new vmess`（实例已存在只告警）。
- **config**：从仓库下载 `config/soga-ss.conf` / `config/soga-vmess.conf` → 覆盖到 `/etc/soga/{ss,vmess}/soga.conf` → `sed` 写入 `node_id` / `webapi_url` / `webapi_key` → `soga start` + `soga enable`（`--no-restart` 跳过）。
- 架构自动识别：`x86_64→amd64`、`aarch64→arm64`、`armv7l→arm`，认不出按 amd64 并告警。
- 非 root 且 `/usr/bin` 不可写时自动加 `sudo`。

---

## 6. `nezha.sh` —— 哪吒探针 Agent 安装

从 `start.sh` v2.1 拆出（choice 5 委托本脚本），也可单独运行。

### 6.1 用法

```bash
./nezha.sh --nezha-ip=1.2.3.4 --nezha-port=8008 --nezha-key=NZ_xxx
./nezha.sh --env=vps.env                 # 从 env 读 nezha_panel_* / nezha_agent_key
./nezha.sh --env=vps.env --dry-run
```

### 6.2 参数

| 长选项                      | 说明                              | 默认                                          |
| --------------------------- | --------------------------------- | --------------------------------------------- |
| `--nezha-ip <ip\|域名>`     | 哪吒面板地址（**必填**）          | `VPS_NEZHA_IP` / env `nezha_panel_ip`         |
| `--nezha-port <端口>`       | 面板端口（**必填**，纯数字）      | `VPS_NEZHA_PORT` / env `nezha_panel_port`     |
| `--nezha-key <secret>`      | Agent Secret（**必填**）          | `VPS_NEZHA_KEY` / env `nezha_agent_key`       |
| `--nezha-tls <true\|false>` | 面板是否 TLS                      | `false` / env `nezha_panel_tls`               |
| `--nz-uuid <uuid>`          | 固定 Agent UUID（不给由面板分配） | `VPS_NZ_UUID`                                 |
| `--env <文件>`              | env 文件路径                      | `vps.env`（存在才加载；指定了却不存在则报错） |

三个必填项缺失时**一次性列全并 exit 2**。

### 6.3 执行细节

- **依赖处理**：官方 `install.sh` 需要 `curl` / `unzip` / `grep` 并用 `sudo unzip -qo` 解压 agent ⇒ 本脚本有 `ensure_unzip()`：检测包管理器（`apt/yum/dnf/pacman/apk/zypper`）自动安装，装不了给出明确指引。
- 下载 `nezhahq/scripts` 的 `agent/install.sh`（下载成功但内容为空会被拦截）。
- 以**环境变量数组**传参（`NZ_SERVER=<ip>:<port>` `NZ_TLS=` `NZ_CLIENT_SECRET=` [`NZ_UUID=`]）执行安装器——**不再用 eval 拼接**，值里含空格/特殊字符也安全；非 root 时用 `sudo env …` 传递。

---

## 7. 公共区段 v2.0（六脚本一致）

六个脚本顶部有**完全相同**的「公共区段 v2.0」（`set -uo pipefail` 行 → `公共区段结束` 标记，共 306 行），包含：

| 组件                                                 | 作用                                                         |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| `init_colors` / `log` `ok` `warn` `err` `step` `die` | 颜色与五级日志（`err` 走 stderr）                            |
| `line` / `section`                                   | 分隔线与分节标题                                             |
| `mask` / `kv` / `kv3`                                | 敏感值脱敏；`kv3` 额外显示**取值来源**                       |
| `have_cmd` / `is_url` / `download`                   | 命令探测 / URL 判断 / curl→wget 下载                         |
| `def_opt` / `def_common_opts` / `usage`              | 选项表注册与自动生成帮助                                     |
| `normalize_args` + `apply_args`                      | **两段式解析**：先把 `--long=val` / `--long val` / `-x val` / `-xval` 统一归一化，再应用；未知选项给「跨脚本请用长选项」提示 |
| `load_env_file`                                      | env 文件解析（`KEY=VALUE`、跳注释、剥引号）                  |
| `cfg_get` / `cfg_src`                                | 四级取值与来源判定（`-` 占位符会归一成空串，避免间接展开取到垃圾值） |
| `miss` / `check_missing`                             | 缺失参数一次性列全                                           |
| `ask` / `confirm`                                    | 交互询问（非 TTY 自动退化为非交互）                          |
| `normalize_bool` / `normalize_yesno`                 | `1/true/yes/on` ↔ `0/false/no/off` 规范化                    |

> **修改公共区段必须同步六份**。校验方法（实测）：
>
> ```bash
> for f in *.sh; do
> b=$(grep -n '^set -uo pipefail' "$f" | head -1 | cut -d: -f1)
> s=$(grep -n '公共区段结束' "$f" | cut -d: -f1)
> md5sum <(sed -n "${b},${s}p" "$f")
> done
> ```
>
> v2.0 脚本（`ddns.sh` / `env.sh` / `ssh.sh`）应为 `25c457aa2fd7957d6db05b00c96376bf`；
> v2.1 脚本（`start.sh` / `proxy.sh` / `nezha.sh`）应为 `c9f1cc5b5838eb9fe055ecadc5c899f3`。
> 两组**唯一差异是 `SCRIPT_VERSION` 一行**（2.0.0 / 2.1.0），其余逐字节相同。

---

## 8. 依赖与运行环境

| 依赖                          | 谁需要                                         | 说明                                        |
| ----------------------------- | ---------------------------------------------- | ------------------------------------------- |
| `bash` 4+                     | 全部                                           | 用了关联数组 `declare -A`、间接展开 `${!i}` |
| `curl`                        | `ddns.sh`（**只用 curl**）、其余任一           | 其余脚本 curl / wget 任一即可               |
| `jq`                          | `ddns.sh`                                      | **可选**，缺失回退 `grep -Po` 解析 JSON     |
| `op`（1Password CLI）≥ 2.18.0 | `env.sh`                                       | Service Account 模式                        |
| `openssh-server`（`sshd`）    | `ssh.sh`                                       | 需要 `sshd -t` 与 systemd/service           |
| `unzip`                       | `nezha.sh`                                     | 缺失时按包管理器自动安装                    |
| root 或 `sudo`                | `ssh.sh`（必须 root）/ `proxy.sh` / `nezha.sh` | 写 `/usr/bin`、`/etc/soga`、`/root/.ssh`    |

---

## 9. 典型组合用法

### 9.1 新装 VPS 一把梭

```bash
# 1) 从 1Password 拉 env（默认产出 vps.env，chmod 600）
./env.sh --token-file=/root/.config/op/token --vault=Infra --item=vps-env

# 2) 一把梭（choice 1）或只装代理+改配置（choice 6）
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6

# 3) 先看一遍再真跑
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6 --dry-run
```

### 9.2 DDNS 单独跑（cron）

见 [§2.5](#25-输出模式与-cron)。`--mode compact` 单行输出适合进日志。

### 9.3 收紧 SSH 后仅用密钥登录

```bash
./ssh.sh --port=2222 --root-login=no --password-auth=no --pubkey-file=/root/.ssh/id_ed25519.pub --choice=1
```

### 9.4 代理分步执行

```bash
./proxy.sh --action=install --soga-version=2.13.4
./proxy.sh --action=config --ss-id=3 --vmess-id=4 --webapi-url=https://panel.example.com --webapi-key=KEY
```

### 9.5 单独装哪吒

```bash
./nezha.sh --nezha-ip=nezha.example.com --nezha-port=443 --nezha-tls=true --nezha-key=NZ_xxx
```

---

## 10. 已知问题与注意事项

1. **`ddns.sh` 用 `PUT` 全量替换记录**：会清掉原有 `ttl` / `comment` 等字段（不是 `PATCH` 合并）。
2. **橙云（proxied）会被 `start.sh` 按记录写死**：`domain1` 的 A / AAAA 两条每轮都传 `--proxy=false` ⇒ 面板里手工开的橙云会被静默覆盖；只有 `domain2` 的 A 记录是 `true`。要全开橙云得改 `start.sh` 里那两行，或改用飞牛内置 DDNS。
3. **橙云有端口白名单**：CF 代理只放行 HTTP `80/8080/8880/2052/2082/2086/2095` + HTTPS `443/2053/2083/2087/2096/8443`；管理端口（如 5666/5667）不在名单，开了必失败。
4. **`ssh.sh` v2 起 `--root-login` 只收 `yes/no`**：旧文档里的 `prohibit-password` 写法会报 exit 2，改用 `--root-login=no --password-auth=no`。
5. **非交互环境缺参 = exit 2**：`start.sh` / `ssh.sh` 在无 TTY 时缺必填项不会询问，而是一次列全后退出；cron 场景要么给全参数，要么 `start.sh` 加 `--force`（跳过缺失步骤）、`ssh.sh` 显式给 `--choice`。
6. **URL 形式的 env 会落到当前目录 `vps.env`**：等于在 CWD 产生一份明文，注意工作目录权限（本地路径形式不复制）。
7. **凭据纪律**：一台机器一个 Token；只放本机 `600` 权限文件；**不要进仓库、不要放 gist**——GitHub Secret Scanning 会扫 secret gist 并通知 Cloudflare **自动吊销** Token（2026-10-12 实际发生过一次）。
8. **`soga update` / `soga start` 返回非零只告警不中断**（刻意设计，实例已存在等场景会返回非零）。
9. **`env.sh` 的 `chmod 600` 在 Windows / 非 POSIX 文件系统上会失败**：只告警，不阻断。
10. **仓库当前 `main/sh/` 还是旧版**（单体 `start.sh` 432 行等）：本 README 对应 UNIFIED v2 六件套，需整体覆盖上传；`start.sh` 对旧版 `ddns.sh` 有 v1 短选项回退，可分批替换。

---

*文档日期：2026-10-15 · 对应 UNIFIED v2：`start.sh` 757 行 / `ddns.sh` 642 行 / `ssh.sh` 568 行 / `proxy.sh` 526 行 / `env.sh` 518 行 / `nezha.sh` 488 行*
