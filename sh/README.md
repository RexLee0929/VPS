# sh/ 脚本使用说明

新装 VPS 的一站式初始化脚本套件 —— 从 1Password 取配置、跑 DDNS、装代理、装探针、收紧 SSH，六个脚本共用一套传参规范。

## 目录

| 章节                                                | 内容                                 |
| --------------------------------------------------- | ------------------------------------ |
| [1. 总览](#1-总览)                                  | 六个脚本的分工、调用关系、统一规范   |
| [2. `start.sh`](#2-startsh--一键部署编排入口)       | 编排入口：执行项、参数、流程、退出码 |
| [3. `ddns.sh`](#3-ddnssh--cloudflare-ddns)          | Cloudflare A / AAAA 记录同步         |
| [4. `env.sh`](#4-envsh--从-1password-拉取-env-文件) | 从 1Password 拉取完整 env            |
| [5. `ssh.sh`](#5-sshsh--ssh-配置与公钥管理)         | sshd_config 与公钥管理               |
| [6. `proxy.sh`](#6-proxysh--soga-代理安装与配置)    | soga 安装与配置                      |
| [7. `nezha.sh`](#7-nezhash--哪吒探针-agent-安装)    | 哪吒探针 Agent 安装                  |
| [8. 公共区段](#8-公共区段六脚本一致)                | 六脚本共用的底层组件                 |
| [9. 依赖](#9-依赖与运行环境)                        | 运行环境要求                         |
| [10. 组合用法](#10-典型组合用法)                    | 常见场景的完整命令                   |
| [11. 注意事项](#11-已知问题与注意事项)              | 坑位清单                             |

---

## 1. 总览

### 1.1 六个脚本的分工

| 脚本           | 作用                                                      | 运行身份         | 依赖                                                         |
| -------------- | --------------------------------------------------------- | ---------------- | ------------------------------------------------------------ |
| **`start.sh`** | **编排入口**：加载 env → 解析配置 → 选执行项 → 委托子脚本 | root 或可 `sudo` | 委托 `ddns.sh` / `proxy.sh` / `nezha.sh` / `ssh.sh`（本地优先，缺失自动下载） |
| `ddns.sh`      | 把本机公网 IP 同步成 Cloudflare A / AAAA 记录             | 任意用户         | 只需 `curl`（`jq` 可选）                                     |
| `env.sh`       | 从 1Password 拉取完整 env 文件到本地                      | 任意用户         | `op` ≥ 2.18.0                                                |
| `ssh.sh`       | 改 `sshd_config` 常用项 + 维护 root 公钥                  | **必须 root**    | `sshd` + systemd / service                                   |
| `proxy.sh`     | soga 代理安装与配置修改                                   | root 或可 `sudo` | `curl` 或 `wget`                                             |
| `nezha.sh`     | 哪吒探针 Agent 安装                                       | root 或可 `sudo` | `curl`/`wget` + `unzip`（缺失自动装）                        |

### 1.2 调用关系

```text
  ┌──────────┐  安全笔记          ┌──────────────────────────────────────┐
  │ env.sh   │ ─────1Password────▶│  vps.env                             │
  └──────────┘   op read          │  （默认输出名，chmod 600）             │
                                  └───────────────┬──────────────────────┘
                                                  │ 供下列脚本 --env 读取
                                  ┌───────────────▼──────────────────────┐
                                  │  start.sh （编排，不自己干活）         │
                                  └───┬───────┬───────┬────────┬─────────┘
                       choice 2 ──────┘       │       │        └────── choice 7 / 8
                       choice 3/4/6 ─────────┘       └── choice 5
                            │                 │              │            │
                            ▼                 ▼              ▼            ▼
                      ┌──────────┐     ┌───────────┐  ┌──────────┐  ┌─────────┐
                      │ ddns.sh  │     │ proxy.sh  │  │ nezha.sh │  │ ssh.sh  │
                      │ CF A/AAAA│     │ soga      │  │ 探针     │  │ sshd    │
                      └──────────┘     └───────────┘  └──────────┘  └─────────┘

  ssh.sh / ddns.sh / proxy.sh / nezha.sh 也都可以单独运行（不依赖 start.sh）
```

`start.sh` 的执行项映射：

```text
  1 全部执行        2 仅 DDNS      3 装代理       4 改配置       5 装哪吒
  6 装代理+改配置   7 SSH 全改     8 SSH 加公钥   0 退出
```

- 委托方式：**长选项同名透传**；子脚本本地优先（脚本所在目录 → `./` → `/usr/local/bin`），都没有就从仓库 raw 下载，并校验 `UNIFIED v2` 标记，旧版会被替换成最新版。
- 调 `ddns.sh` 额外有 **v1 回退**：检测到旧版（无 `UNIFIED v2` 标记）自动切回旧短选项，因此可以分批替换脚本。

### 1.3 统一规范（六脚本通用）

1. **长选项是唯一权威接口**：`--key value`、`--key=value`、`-k value`、`-kvalue` 四种写法都认。
   短选项仅为兼容保留，**且跨脚本含义不同** —— `-t` 在 `env.sh` 是 token、在 `ddns.sh` 是记录类型；`-R` 在 `ssh.sh` 是 root 登录、在 `start.sh` 是 DNS 前缀。

   > [!IMPORTANT]
   > **串联执行一律用长选项。** 敲错短选项最坏的结果是把 `PermitRootLogin home` 这类值写进配置。

2. **取值优先级**：`命令行 > VPS_* 环境变量 > env 文件 > 内置默认 >（交互询问 / 报错）`。
   参数摘要会用 `kv3` 标注每个值**来自哪里**（命令行 / 环境变量 / env文件 / 默认值）。

3. **缺失参数一次性列全**：缺几项列几项，并给出可复制的补全方式。

4. **通用开关**：`--dry-run`、`--yes`、`--no-color` / `--color`、`--verbose`、`-h` / `--help`、`--version`。

5. **敏感值脱敏**：只显示前 4 位 + 后 4 位 + 长度（≤8 字符显示 `********`），日志可安全外发。

6. **不接受位置参数**：全部用选项传参，误给位置参数直接报错。

7. **`set -uo pipefail`**（刻意不用 `-e`），`IFS=$'\n\t'`。

---

## 2. `start.sh` —— 一键部署编排入口

加载 env → 解析配置 → 选执行项 → 按需委托子脚本。全部流程分 5 段打印，每段都带来源标注。

### 2.1 快速开始

```bash
curl -L "https://raw.githubusercontent.com/RexLee0929/VPS/main/sh/start.sh" -o start.sh
chmod +x start.sh

# 先看一眼会做什么（强烈建议）
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6 --dry-run

# 确认无误后真跑
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6
```

### 2.2 执行项 `--choice` / `-C`

|  值  | 含义                                                 | 委托                        |
| :--: | ---------------------------------------------------- | --------------------------- |
| `1`  | 全部执行（DDNS → 装代理 → 改配置 → 装探针 →〔SSH〕） | 全部                        |
| `2`  | 仅 DDNS                                              | `ddns.sh`                   |
| `3`  | 仅安装代理（soga）                                   | `proxy.sh --action=install` |
| `4`  | 仅修改代理配置                                       | `proxy.sh --action=config`  |
| `5`  | 仅安装哪吒探针                                       | `nezha.sh`                  |
| `6`  | 安装代理 + 修改配置（**最常用**）                    | `proxy.sh --action=both`    |
| `7`  | SSH 改全部并重启                                     | `ssh.sh --choice=1`         |
| `8`  | SSH 仅添加公钥                                       | `ssh.sh --choice=2`         |
| `0`  | 退出                                                 | —                           |

> [!NOTE]
> `--choice=1` 的 SSH 步骤是**条件执行**的：只有你提供了任何 SSH 设置（`--ssh-*` / `VPS_SSH_*` / env 文件里的 `ssh_*` 键）才会带上，否则打印「跳过 SSH 步骤」。这是为了避免只想装代理却把 sshd 重启一遍。

不给 `--choice` 时：交互终端进菜单；**非交互（无 TTY）直接 exit 2**。

### 2.3 参数

**基础参数**

| 长选项                  | 短选项 | 说明                                 | 默认                   |
| ----------------------- | :----: | ------------------------------------ | ---------------------- |
| `--env <文件\|URL>`     |  `-f`  | env 文件路径或 `http(s)://` 地址     | `vps.env`              |
| `--prefix <前缀>`       |  `-R`  | DNS 记录前缀（拼成 `<前缀>.<域名>`） | 空（按根域名，会告警） |
| `--ss-id <id>`          |  `-S`  | Shadowsocks 节点 ID                  | 空                     |
| `--vmess-id <id>`       |  `-V`  | Vmess 节点 ID                        | 空                     |
| `--choice <0-8>`        |  `-C`  | 执行项                               | 交互选择               |
| `--nz-uuid <uuid>`      |  `-U`  | 哪吒 Agent UUID（不给由面板分配）    | 空                     |
| `--soga-version <版本>` |   —    | soga 版本，透传 `proxy.sh`           | `2.13.4`               |

**委托与落盘**

| 长选项                  | 说明                                 | 默认            |
| ----------------------- | ------------------------------------ | --------------- |
| `--ddns-script <路径>`  | 指定 `ddns.sh` 路径                  | 自动查找 / 下载 |
| `--proxy-script <路径>` | 指定 `proxy.sh` 路径                 | 自动查找 / 下载 |
| `--nezha-script <路径>` | 指定 `nezha.sh` 路径                 | 自动查找 / 下载 |
| `--ssh-script <路径>`   | 指定 `ssh.sh` 路径                   | 自动查找 / 下载 |
| `--save-env <路径>`     | 把最终配置写回 env 文件（权限 600）  | 不写            |
| `--force`               | 参数缺失时**跳过对应步骤**而不是退出 | 关              |

**env 缺失时的手动补参**（优先级最高，也可用对应的 `VPS_*` 环境变量）

```text
--cf-key  --cf-email  --domain1  --domain2
--webapi-url  --webapi-key
--nezha-ip  --nezha-port  --nezha-tls  --nezha-key
```

**SSH 参数**（v2.2 起，全部透传给 `ssh.sh`；**留空即用 `ssh.sh` 自己的默认值**）

| 长选项                            | 说明                                   | 透传目标            |
| --------------------------------- | -------------------------------------- | ------------------- |
| `--ssh-port <端口>`               | SSH 端口                               | `--port`            |
| `--ssh-root-login <yes\|no>`      | PermitRootLogin                        | `--root-login`      |
| `--ssh-password-auth <yes\|no>`   | PasswordAuthentication                 | `--password-auth`   |
| `--ssh-empty-passwords <yes\|no>` | PermitEmptyPasswords                   | `--empty-passwords` |
| `--ssh-max-auth-tries <n>`        | MaxAuthTries                           | `--max-auth-tries`  |
| `--ssh-pubkey-auth <yes\|no>`     | PubkeyAuthentication                   | `--pubkey-auth`     |
| `--ssh-pubkey <公钥整行>`         | 直接给公钥字符串                       | `--pubkey`          |
| `--ssh-pubkey-file <文件>`        | 从文件读公钥                           | `--pubkey-file`     |
| `--ssh-pubkey-name <名字>`        | 从 env 读 `pubkey_<名字>`              | `--pubkey-name`     |
| `--ssh-config <路径>`             | `sshd_config` 路径                     | `--config`          |
| `--ssh-action <1\|2>`             | SSH 动作（**仅 `--choice=1` 时生效**） | `--choice`          |
| `--ssh-skip-restart`              | 改完不重启 SSH                         | `--skip-restart`    |
| `--ssh-env <文件>`                | 传给 `ssh.sh` 的 env 文件              | `--env`             |

### 2.4 env 文件与环境变量

只解析 `KEY=VALUE` 行（跳过 `#` 注释与空行，自动剥掉值两端的 `"` `'`）。读取的键：

```ini
cf_key  cf_email  domain1  domain2  record_prefix
v2board_webapi_url  v2board_webapi_key
nezha_panel_ip  nezha_panel_port  nezha_panel_tls  nezha_agent_key
ssh_port  ssh_permit_root_login  ssh_password_auth  ssh_permit_empty_passwords
ssh_max_auth_tries  ssh_pubkey_auth  ssh_config          # v2.2，键名与 ssh.sh 完全一致
```

> [!TIP]
> `--save-env=vps.env` 写回时也会带上 `ssh_*` 键（只写非空的），所以生成出来的 `vps.env` 可以直接喂给 `ssh.sh`。

查找逻辑：URL → 下载到当前目录 `vps.env`；本地路径存在 → 直接加载（不再复制）；找不到 → 进入手动传参模式（交互终端逐项询问，非交互一次列全后 exit 2）。

对应环境变量：

```text
VPS_CF_KEY  VPS_CF_EMAIL  VPS_DOMAIN1  VPS_DOMAIN2  VPS_PREFIX
VPS_WEBAPI_URL  VPS_WEBAPI_KEY  VPS_SOGA_VERSION
VPS_NEZHA_IP  VPS_NEZHA_PORT  VPS_NEZHA_TLS  VPS_NEZHA_KEY
VPS_SS_ID  VPS_VMESS_ID  VPS_CHOICE  VPS_NZ_UUID  VPS_ENV
VPS_SSH_PORT  VPS_SSH_ROOT_LOGIN  VPS_SSH_PASSWORD_AUTH  VPS_SSH_EMPTY_PASSWORDS
VPS_SSH_MAX_AUTH_TRIES  VPS_SSH_PUBKEY_AUTH  VPS_SSH_PUBKEY  VPS_SSH_CONFIG  VPS_SSH_CHOICE
```

### 2.5 五段式执行流程

|  段  | 内容                                                         |
| :--: | ------------------------------------------------------------ |
| 1/5  | 加载 env 文件（缺失不退出，转手动模式）                      |
| 2/5  | 配置解析结果（每项标注来源，敏感值脱敏）                     |
| 3/5  | 选择执行项（交互菜单或 `--choice`）                          |
| 4/5  | 参数完整性检查（只检查本次 choice 需要的项；缺项则询问或一次列全；`--force` 改为跳过） |
| 5/5  | 执行（`--dry-run` 全程只打印）                               |

### 2.6 DDNS 行为（choice 1 / 2）

需要 `cf_key` + `domain1`，对每个域名调用一次 `ddns.sh`：

| 记录                                        | 类型 |  橙云   |
| ------------------------------------------- | :--: | :-----: |
| `<prefix>.<domain1>`                        |  A   | `false` |
| `<prefix>-v6.<domain1>`                     | AAAA | `false` |
| `<prefix>.<domain2>`（仅 `domain2` 非空时） |  A   | `true`  |

不给 `--prefix` 时按根域名处理并告警。

### 2.7 SSH 联动（v2.2 新增）

想动 SSH 有两种方式，效果等价：

```bash
# 方式一：直接用 start.sh（推荐，参数会被透传）
./start.sh --choice=7 --ssh-port=2222 --ssh-root-login=no \
           --ssh-password-auth=no --ssh-pubkey-file=/root/.ssh/id_ed25519.pub --dry-run

# 方式二：先跑 start.sh 保证 env 就绪，再单独调 ssh.sh
./ssh.sh --env=vps.env --port=2222 --root-login=no --password-auth=no --choice=1
```

- **只透传非空值**：没给的参数不会传，`ssh.sh` 用自己那份默认值（`22 / yes / yes / no / 3 / yes`）—— 不维护第二套默认值。
- **env 文件贯通**：`--ssh-env` 不给时，默认把 `start.sh` 正在用的 env 文件转给 `ssh.sh`，因此 `pubkey_<名字>` 这类只存在于 env 里的键也能被解析。
- **锁门提醒**：若 `--ssh-password-auth=no` 却没给任何公钥，`start.sh` 会直接警告「会把自己锁在门外」；`--ssh-root-login=no` 会提醒确认有普通用户可登录。

### 2.8 退出码

|  码  | 含义                                           |
| :--: | ---------------------------------------------- |
| `0`  | 全部成功（**包含** `--force` 主动跳过的步骤）  |
| `1`  | 有步骤失败（子脚本失败会如实上报，不会被吞掉） |
| `2`  | 选项或参数错误（未知选项、必填缺失、取值非法） |

---

## 3. `ddns.sh` —— Cloudflare DDNS

把本机公网 IP 同步到 Cloudflare；记录不存在时**自动创建**，IP 无变化则跳过。

### 3.1 用法

```bash
./ddns.sh --domain=example.com --prefix=home
./ddns.sh --domain=example.com --record=home.example.com --type=AAAA --proxy=false
./ddns.sh --key="$TOKEN" --domain=example.com --prefix=home --mode=compact   # cron 用
```

### 3.2 参数

| 长选项                  | 短选项 | 必填 | 说明                                    | 其它来源                                            |
| ----------------------- | :----: | :--: | --------------------------------------- | --------------------------------------------------- |
| `--key <token>`         |  `-k`  |  ✅   | Cloudflare **API Token**（Bearer 认证） | `VPS_CF_KEY` / env `cf_key`                         |
| `--domain <域名>`       |  `-d`  |  ✅   | 主域名，如 `example.com`                | `VPS_DDNS_DOMAIN` / env `domain`                    |
| `--record <记录名>`     |  `-r`  |  ⬜   | 完整记录名，如 `home.example.com`       | `VPS_DDNS_RECORD` / env `record`                    |
| `--prefix <前缀>`       |   —    |  ⬜   | 前缀，与 `--domain` 组合                | `VPS_DDNS_PREFIX` / env `record_prefix`             |
| `--type <A\|AAAA>`      |  `-t`  |  ❌   | 记录类型（大写化处理）                  | `VPS_DDNS_TYPE` / env `type`，默认 `A`              |
| `--proxy <true\|false>` |  `-p`  |  ❌   | 是否开 CF 橙云代理                      | `VPS_DDNS_PROXY` / env `proxy`，默认 `false`        |
| `--email <邮箱>`        |  `-e`  |  ❌   | **兼容保留**，Token 模式不使用          | env `cf_email`                                      |
| `--mode <模式>`         |   —    |  ❌   | 输出模式 `color \| plain \| compact`    | `VPS_DDNS_MODE` / env `mode`，默认自动（TTY→color） |

记录名推导优先级：`--record` > `--prefix` + `--domain` > `--domain`（根域名，会告警）。

### 3.3 执行流程

1. 取公网 IP：依次尝试 `ip.sb` / `icanhazip.com` / `ifconfig.me/ip`（A 用 `curl -4`，AAAA 用 `curl -6`），并做格式校验；
2. `GET /zones?name=<domain>` 取 Zone ID；
3. `GET /zones/<zone>/dns_records?type=&name=` 查现有记录；
4. 记录存在 → IP 有变化则 `PUT` 更新，无变化跳过；不存在 → `POST` 创建；
5. 打印「执行结果」汇总块。

### 3.4 关于认证

- **只能填 API Token，不要填 Global API Key**（脚本走 `Authorization: Bearer`）。
- Token 权限需要 `Zone.DNS:Edit` **和** `Zone:Read` 两个，Zone Resources 覆盖目标域名。
- 该 Token 与 Caddy DNS-01 证书、ddns-go、飞牛内置 DDNS **可共用一个**（权限完全重合）。
- `VPS_CF_KEY` 环境变量与 env 文件的 `cf_key` 键**回退是真正生效的**（旧仓库版把变量硬清空，必须 `-k` 传值）。

### 3.5 cron

`--mode=compact` 只输出一行，适合进日志：

```cron
*/2 * * * * /root/sh/ddns.sh --key "TOKEN" --domain "example.com" --prefix "home" \
  --type A --proxy false --mode compact >> /root/ddns.log 2>&1
```

---

## 4. `env.sh` —— 从 1Password 拉取 env 文件

把 1Password 里「一条安全笔记 = 完整 env」拉到本机，**默认输出 `vps.env`**（与 `start.sh` 的默认读取值一致，拉完可以直接跑 `start.sh`）。

### 4.1 用法

```bash
./env.sh --token=ops_xxxx --vault=Infra --item=vps-env
./env.sh --token-file=/root/.config/op/token --ref=op://Infra/vps-env/notesPlain
./env.sh --vault=Infra --item=vps-env --dry-run
./env.sh --list-keys                       # 只列已有 vps.env 的 KEY 名
```

### 4.2 参数

| 长选项                | 短选项 | 说明                                         | 默认 / 其它来源                              |
| --------------------- | :----: | -------------------------------------------- | -------------------------------------------- |
| `--token <token>`     |  `-t`  | Service Account token（`ops_` 开头）         | `VPS_OP_TOKEN` / `$OP_SERVICE_ACCOUNT_TOKEN` |
| `--token-file <文件>` |  `-T`  | 从文件读 token（首行，自动去换行）           | —                                            |
| `--ref <op://…>`      |  `-r`  | 完整引用 `<库>/<条目>/<字段>`                | `VPS_OP_REF`                                 |
| `--vault <库>`        |  `-v`  | 保管库名（不给 `--ref` 时必填）              | `VPS_OP_VAULT`                               |
| `--item <条目>`       |  `-i`  | 条目名（不给 `--ref` 时必填）                | `VPS_OP_ITEM`                                |
| `--field <字段>`      |  `-F`  | 字段名，安全笔记正文 = `notesPlain`          | `VPS_OP_FIELD`，默认 `notesPlain`            |
| `--out <文件>`        |  `-o`  | 输出文件                                     | `VPS_OP_OUT`，默认 `vps.env`                 |
| `--list-keys`         |   —    | **只读**：列出已有 env 文件的 KEY 名，不拉取 | —                                            |

token 优先级：`-t` > `--token-file` > `$OP_SERVICE_ACCOUNT_TOKEN`。

### 4.3 行为要点

- 检测不到 `op` 会打印官方一行安装法；版本 < 2 直接退出，< 2.18.0 告警（Service Account 需要 ≥ 2.18.0）。
- token 不是 `ops_` 开头会告警（可能是个人账号凭据）。
- 落盘前自动备份 `vps.env.bak.<时间戳>`；覆盖需确认（`--yes` 跳过）；写入后 `chmod 600`。
- **全程不打印 token、不打印任何值**；结果校验只列 KEY 名，并检查 `start.sh` 需要的 10 个核心键（`cf_key` / `cf_email` / `domain1` / `domain2` / `v2board_webapi_url` / `v2board_webapi_key` / `nezha_panel_ip` / `nezha_panel_port` / `nezha_panel_tls` / `nezha_agent_key`），缺哪些会列出来。
- `op read` 失败会直接给出三种常见原因：引用写错（大小写敏感）、SA 未授权该保管库、token 过期或被撤销。

> [!WARNING]
> `-t "ops_..."` 会进 shell 历史。介意的话用 `--token-file`。

---

## 5. `ssh.sh` —— SSH 配置与公钥管理

改 `sshd_config` 常用项 + 维护 `/root/.ssh/authorized_keys`，改完自动校验语法并重启服务。**必须以 root 运行**（`--dry-run` 除外）。

### 5.1 用法

```bash
./ssh.sh --port=2222 --root-login=no --password-auth=no \
         --pubkey="$(cat ~/.ssh/id_ed25519.pub)" --choice=1
./ssh.sh --env=ssh.env --choice=2                    # 仅加公钥
./ssh.sh --port=2222 --choice=1 --skip-restart --dry-run
```

### 5.2 参数

| 长选项                        | 短选项 | 说明                                       | 默认                      |
| ----------------------------- | :----: | ------------------------------------------ | ------------------------- |
| `--env <文件\|URL>`           |  `-f`  | env 文件路径或 URL                         | `ssh.env`（不存在不报错） |
| `--port <端口>`               |  `-P`  | `Port`（1-65535）                          | `22`                      |
| `--root-login <yes\|no>`      |  `-R`  | `PermitRootLogin`                          | `yes`                     |
| `--password-auth <yes\|no>`   |  `-A`  | `PasswordAuthentication`                   | `yes`                     |
| `--empty-passwords <yes\|no>` |  `-E`  | `PermitEmptyPasswords`                     | `no`                      |
| `--max-auth-tries <n>`        |  `-M`  | `MaxAuthTries`                             | `3`                       |
| `--pubkey-auth <yes\|no>`     |  `-U`  | `PubkeyAuthentication`                     | `yes`                     |
| `--pubkey <公钥整行>`         |  `-K`  | 直接给公钥字符串                           | —                         |
| `--pubkey-file <文件>`        |   —    | 从文件读公钥（取首行）                     | —                         |
| `--pubkey-name <名字>`        |  `-N`  | 从 env 读 `pubkey_<名字>`                  | —                         |
| `--config <路径>`             |   —    | `sshd_config` 路径                         | `/etc/ssh/sshd_config`    |
| `--choice <0\|1\|2>`          |  `-C`  | `1` 改全部并重启 / `2` 仅加公钥 / `0` 退出 | 交互                      |
| `--skip-restart`              |   —    | 不重启 SSH 服务（配合 `--choice=1`）       | 关                        |

env 文件键（默认 `ssh.env`）：`ssh_port` `ssh_permit_root_login` `ssh_password_auth` `ssh_permit_empty_passwords` `ssh_max_auth_tries` `ssh_pubkey_auth` `ssh_choice` `ssh_config` `pubkey_<名字>`。

环境变量：`VPS_SSH_ENV` `VPS_SSH_PORT` `VPS_SSH_ROOT_LOGIN` `VPS_SSH_PASSWORD_AUTH` `VPS_SSH_EMPTY_PASSWORDS` `VPS_SSH_MAX_AUTH_TRIES` `VPS_SSH_PUBKEY_AUTH` `VPS_SSH_PUBKEY` `VPS_SSH_CONFIG` `VPS_SSH_CHOICE`。

公钥来源优先级：`--pubkey` > `--pubkey-file` > `--pubkey-name`（env） > 交互。

### 5.3 关键行为

- **改前自动备份**：首次修改时 `cp -a sshd_config sshd_config.bak.<时间戳>`。
- **定向替换**：`sed` 删掉原有（含被注释的）同名项，新值追加到文件末尾 —— 与 sshd「最后一条生效」的解析规则一致。
- **公钥去重**：`grep -qxF` 命中则跳过；确保 `/root/.ssh` 为 `700`、`authorized_keys` 为 `600` 且属 `root:root`。
- **重启前先校验**：`sshd -t`，失败直接退出不重启；重启优先 `systemctl restart sshd`，退 `ssh`，再退 `service`。

> [!CAUTION]
> 默认值偏宽松（root 登录 + 密码认证全开），只适合一次性初始化。收紧示例：
> `./ssh.sh --root-login=no --password-auth=no --pubkey-file=~/.ssh/id_ed25519.pub --choice=1`
> 另：**改端口前先确认新端口已在防火墙放行**，否则可能把自己锁在门外。

---

## 6. `proxy.sh` —— soga 代理安装与配置

从 `start.sh` 拆出的独立脚本（choice 3/4/6 会委托它），也可单独运行。

### 6.1 用法

```bash
./proxy.sh --action=install
./proxy.sh --action=install --soga-version=2.14.0
./proxy.sh --action=config --ss-id=3 --vmess-id=4 --webapi-url=https://a --webapi-key=K
./proxy.sh --env=vps.env --dry-run
```

### 6.2 参数

| 长选项                             | 短选项 | 说明                                    | 默认 / 其它来源                               |
| ---------------------------------- | :----: | --------------------------------------- | --------------------------------------------- |
| `--action <install\|config\|both>` |  `-a`  | 只装 / 只配 / 装+配                     | `both`                                        |
| `--soga-version <版本>`            |  `-s`  | soga 版本（格式 `x.y.z`）               | `VPS_SOGA_VERSION`，默认 `2.13.4`             |
| `--arch <amd64\|arm64\|arm>`       |   —    | 目标架构                                | 自动检测                                      |
| `--ss-id <id>`                     |  `-S`  | Shadowsocks 节点 ID（config/both 必填） | `VPS_SS_ID`                                   |
| `--vmess-id <id>`                  |  `-V`  | Vmess 节点 ID（config/both 必填）       | `VPS_VMESS_ID`                                |
| `--webapi-url <url>`               |   —    | v2board webapi 地址（config/both 必填） | `VPS_WEBAPI_URL` / env `v2board_webapi_url`   |
| `--webapi-key <key>`               |   —    | v2board webapi key（config/both 必填）  | `VPS_WEBAPI_KEY` / env `v2board_webapi_key`   |
| `--env <文件>`                     |  `-f`  | env 文件路径                            | `vps.env`（存在才加载；指定了却不存在则报错） |
| `--no-restart`                     |   —    | 配置写入后不启动 / 不启用实例           | 关                                            |

### 6.3 两条硬规则

1. **soga 默认装 2.13.4**，要换版本用 `--soga-version`。
2. **`--action=config / both` 的四个对接参数必须显式传入**，空白（含纯空格）一律报错 **exit 2**，绝不拿空值写配置。只想安装用 `--action=install`。

### 6.4 执行细节

- **install**：下载 `vaxilu/soga-cmd` 最新 release 到 `/usr/bin/soga` → `soga update <版本>` → `soga new ss` / `soga new vmess`（实例已存在只告警）。
- **config**：从仓库下载 `config/soga-ss.conf` / `config/soga-vmess.conf` → 覆盖到 `/etc/soga/{ss,vmess}/soga.conf` → `sed` 写入 `node_id` / `webapi_url` / `webapi_key` → `soga start` + `soga enable`（`--no-restart` 跳过）。
- 架构自动识别：`x86_64 → amd64`、`aarch64 → arm64`、`armv7l → arm`，认不出按 `amd64` 处理并告警。
- 非 root 且 `/usr/bin` 不可写时自动加 `sudo`。

---

## 7. `nezha.sh` —— 哪吒探针 Agent 安装

从 `start.sh` 拆出的独立脚本（choice 5 会委托它），也可单独运行。

### 7.1 用法

```bash
./nezha.sh --nezha-ip=1.2.3.4 --nezha-port=8008 --nezha-key=NZ_xxx
./nezha.sh --env=vps.env                 # 从 env 读 nezha_panel_* / nezha_agent_key
./nezha.sh --env=vps.env --dry-run
```

### 7.2 参数

| 长选项                      | 说明                              | 默认 / 其它来源                               |
| --------------------------- | --------------------------------- | --------------------------------------------- |
| `--nezha-ip <ip\|域名>`     | 哪吒面板地址（**必填**）          | `VPS_NEZHA_IP` / env `nezha_panel_ip`         |
| `--nezha-port <端口>`       | 面板端口（**必填**，纯数字）      | `VPS_NEZHA_PORT` / env `nezha_panel_port`     |
| `--nezha-key <secret>`      | Agent Secret（**必填**）          | `VPS_NEZHA_KEY` / env `nezha_agent_key`       |
| `--nezha-tls <true\|false>` | 面板是否 TLS                      | env `nezha_panel_tls`，默认 `false`           |
| `--nz-uuid <uuid>`          | 固定 Agent UUID（不给由面板分配） | `VPS_NZ_UUID`                                 |
| `--env <文件>`              | env 文件路径                      | `vps.env`（存在才加载；指定了却不存在则报错） |

三个必填项缺失时**一次性列全并 exit 2**。

### 7.3 执行细节

- **依赖处理**：官方 `install.sh` 需要 `curl` / `unzip` / `grep`，并用 `sudo unzip -qo` 解压 agent ⇒ 本脚本有 `ensure_unzip()`：按包管理器（`apt` / `yum` / `dnf` / `pacman` / `apk` / `zypper`）自动安装，装不了给明确指引。
- 下载 `nezhahq/scripts` 的 `agent/install.sh`（下载「成功但内容为空」会被拦截）。
- 以**环境变量数组**传参（`NZ_SERVER=<ip>:<port>`、`NZ_TLS=`、`NZ_CLIENT_SECRET=`〔、`NZ_UUID=`〕）执行安装器 —— **不再用 `eval` 拼接**，值里含空格或特殊字符也安全；非 root 时用 `sudo env …` 传递。

---

## 8. 公共区段（六脚本一致）

六个脚本顶部有**完全相同**的「公共区段 v2.0」（从 `set -uo pipefail` 行到 `公共区段结束` 标记，共 306 行），包含：

| 组件                                                 | 作用                                                         |
| ---------------------------------------------------- | ------------------------------------------------------------ |
| `init_colors` / `log` `ok` `warn` `err` `step` `die` | 颜色与五级日志（`err` 走 stderr）                            |
| `line` / `section`                                   | 分隔线与分节标题                                             |
| `mask` / `kv` / `kv3`                                | 敏感值脱敏；`kv3` 额外显示**取值来源**                       |
| `have_cmd` / `is_url` / `download`                   | 命令探测 / URL 判断 / `curl → wget` 下载                     |
| `def_opt` / `def_common_opts` / `usage`              | 选项表注册与自动生成帮助                                     |
| `normalize_args` + `apply_args`                      | **两段式解析**：先归一化 `--long=val` / `--long val` / `-x val` / `-xval`，再应用；未知短选项会给「跨脚本请用长选项」提示 |
| `load_env_file`                                      | env 文件解析（`KEY=VALUE`、跳注释、剥引号）                  |
| `cfg_get` / `cfg_src`                                | 四级取值与来源判定（`-` 占位符会归一成空串，避免间接展开取到垃圾值） |
| `miss` / `check_missing`                             | 缺失参数一次性列全                                           |
| `ask` / `confirm`                                    | 交互询问（非 TTY 自动退化为非交互）                          |
| `normalize_bool` / `normalize_yesno`                 | `1/true/yes/on` ↔ `0/false/no/off` 规范化                    |

> [!IMPORTANT]
> **修改公共区段必须同步六份。** 校验方法（排除各自不同的 `SCRIPT_VERSION` 行后，六份应当逐字节相同）：

```bash
for f in *.sh; do
  b=$(grep -n '^set -uo pipefail' "$f" | head -1 | cut -d: -f1)
  e=$(grep -n '公共区段结束' "$f" | cut -d: -f1)
  printf '%-10s ' "$f"
  sed -n "${b},${e}p" "$f" | grep -v '^SCRIPT_VERSION=' | md5sum
done
# 期望六行完全相同：99d7347a16bc97e33f16e5e7ccd3ee74
```

---

## 9. 依赖与运行环境

| 依赖                          | 谁需要                                         | 说明                                         |
| ----------------------------- | ---------------------------------------------- | -------------------------------------------- |
| `bash` 4+                     | 全部                                           | 用了关联数组 `declare -A` 与间接展开 `${!i}` |
| `curl`                        | `ddns.sh`（**只用 curl**）、其余任一           | 其余脚本 `curl` / `wget` 任有其一即可        |
| `jq`                          | `ddns.sh`                                      | **可选**，缺失时回退 `grep -Po` 解析 JSON    |
| `op`（1Password CLI）≥ 2.18.0 | `env.sh`                                       | Service Account 模式                         |
| `openssh-server`（`sshd`）    | `ssh.sh`                                       | 需要 `sshd -t` 与 systemd / service          |
| `unzip`                       | `nezha.sh`                                     | 缺失时按包管理器自动安装                     |
| root 或 `sudo`                | `ssh.sh`（必须 root）/ `proxy.sh` / `nezha.sh` | 要写 `/usr/bin`、`/etc/soga`、`/root/.ssh`   |

---

## 10. 典型组合用法

### 10.1 新装 VPS 一把梭

```bash
# 1) 从 1Password 拉 env（默认产出 vps.env，chmod 600）
./env.sh --token-file=/root/.config/op/token --vault=Infra --item=vps-env

# 2) 先看一遍会做什么
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6 --dry-run

# 3) 真跑（choice 6 = 装代理 + 改配置）
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6
```

### 10.2 连 SSH 一起初始化（choice 1 + SSH 参数）

```bash
./start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=1 \
           --ssh-port=2222 --ssh-root-login=no --ssh-password-auth=no \
           --ssh-pubkey-file=/root/.ssh/id_ed25519.pub --dry-run
```

`--choice=1` 会自动带上 SSH 步骤（因为给了 `--ssh-*`）。

### 10.3 收紧 SSH 后仅用密钥登录

```bash
./ssh.sh --port=2222 --root-login=no --password-auth=no \
         --pubkey-file=/root/.ssh/id_ed25519.pub --choice=1
```

### 10.4 DDNS 单独跑（cron）

见 [§3.5](#35-cron)，`--mode=compact` 单行输出适合进日志。

### 10.5 代理分步执行

```bash
./proxy.sh --action=install --soga-version=2.13.4
./proxy.sh --action=config --ss-id=3 --vmess-id=4 \
           --webapi-url=https://panel.example.com --webapi-key=KEY
```

### 10.6 单独装哪吒

```bash
./nezha.sh --nezha-ip=nezha.example.com --nezha-port=443 --nezha-tls=true --nezha-key=NZ_xxx
```

---

## 11. 已知问题与注意事项

1. **`ddns.sh` 用 `PUT` 全量替换记录**：会清掉原有 `ttl` / `comment` 等字段（不是 `PATCH` 合并）。
2. **橙云（proxied）被 `start.sh` 按记录写死**：`domain1` 的 A / AAAA 两条每轮都传 `--proxy=false`，面板里手工开的橙云会被静默覆盖；只有 `domain2` 的 A 记录是 `true`。要全开橙云得改 `start.sh` 里那两行，或改用飞牛内置 DDNS。
3. **橙云有端口白名单**：CF 代理只放行 HTTP `80/8080/8880/2052/2082/2086/2095` + HTTPS `443/2053/2083/2087/2096/8443`；管理端口（如 `5666/5667`）不在名单，开了必失败。
4. **`ssh.sh` 的 `--root-login` 只收 `yes` / `no`**：`prohibit-password` 这类值会报 exit 2，要「仅密钥登录」用 `--root-login=no --password-auth=no` 组合。
5. **SSH 有锁门风险**：改端口前先放行新端口；关密码登录前先确认公钥能登（`start.sh` 会替你检查并警告）。
6. **非交互环境缺参 = exit 2**：`start.sh` / `ssh.sh` 在无 TTY 时缺必填项不会询问，而是一次列全后退出。cron 场景要么给全参数，要么 `start.sh` 加 `--force`（跳过缺失步骤）、`ssh.sh` 显式给 `--choice`。
7. **URL 形式的 env 会落到当前目录 `vps.env`**：等于在 CWD 留一份明文，注意工作目录权限（本地路径形式不会复制）。
8. **凭据纪律**：一台机器一个 Token；只放本机 `600` 权限文件；**不要进仓库、不要放 gist** —— GitHub Secret Scanning 会扫 secret gist 并通知 Cloudflare **自动吊销** Token（2026-10-12 实际发生过一次）。
9. **`soga update` / `soga start` 返回非零只告警不中断**（刻意设计：实例已存在等场景会返回非零）。
10. **`env.sh` 的 `chmod 600` 在 Windows / 非 POSIX 文件系统上会失败**：只告警，不阻断。
11. **从旧版单体脚本迁移**：v2 起**不再把 `cf_key` / `webapi_key` / `nezha_agent_key` 明文打屏**（全走 `mask()`）；代理与探针逻辑已拆到 `proxy.sh` / `nezha.sh`；本地 env 文件不再 `cp -f` 复制成 `vps.env`（少一份明文副本）。

---

*最后更新：2026-10-15*
