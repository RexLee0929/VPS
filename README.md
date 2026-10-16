# VPS 自用脚本集

自用 VPS 初始化与日常运维脚本、配置模板。四个目录各管一件事：

| 目录                                       | 内容                                   | 什么时候用                                           |
| ------------------------------------------ | -------------------------------------- | ---------------------------------------------------- |
| [`Setup/`](#setup--六脚本无人值守部署套件) | 六脚本无人值守部署套件（UNIFIED v2）   | 新 VPS 一把梭：env → DDNS → 代理 → 探针 → SSH        |
| [`ToolBox/`](#toolbox--交互式运维工具箱)   | 交互式运维菜单（v3.0.0）               | 日常点点点：BBR / swap / Caddy / Aria2 / 解压 / 测速 |
| [`Script/`](#script--备份脚本)             | Docker Compose 备份脚本（v5.2）        | 定期备份 compose 项目                                |
| [`config/`](#config--配置模板)             | 配置模板（soga / XrayR / aria2 / env） | 单独装机时抄作业                                     |

> [!NOTE]
> 每个子目录都有自己的详细 README，本页只做总览与快速开始。本页所有命令均按仓库当前路径（`Setup/`、`ToolBox/`、`Script/`）书写。

---

## Setup/ — 六脚本无人值守部署套件

`start.sh` 做编排，`ddns.sh` / `proxy.sh` / `nezha.sh` / `ssh.sh` 干活，`env.sh` 从 1Password 拉配置。六个脚本共用一套传参规范（套件版本 UNIFIED v2）：

- **长选项是唯一权威接口**（`--key value` / `--key=value` / `-k value` / `-kvalue` 都认）；短选项跨脚本含义不同，串联执行一律用长选项
- 取值优先级：`命令行 > VPS_* 环境变量 > env 文件 > 内置默认`
- 敏感值脱敏后打印；缺失参数一次列全；`--dry-run` 全程只打印不落地
- 退出码：`0` 成功（含主动跳过）/ `1` 有步骤失败 / `2` 选项参数错误

| 脚本       | 作用                                                     | 运行身份              |
| ---------- | -------------------------------------------------------- | --------------------- |
| `start.sh` | 编排入口，执行项 0-8（choice 1 一把梭、7/8 动 SSH）      | root 或可 sudo        |
| `ddns.sh`  | Cloudflare A / AAAA 记录同步，记录不存在自动创建         | 任意用户（只需 curl） |
| `env.sh`   | 从 1Password 拉完整 env 到 `vps.env`（没装 op 会自动装） | 任意用户              |
| `proxy.sh` | soga 安装与配置（改完配置强制 `restart`，保证生效）      | root 或可 sudo        |
| `nezha.sh` | 哪吒探针 Agent 安装                                      | root 或可 sudo        |
| `ssh.sh`   | `sshd_config` 常用项 + root 公钥，改前备份、改后校验重启 | 必须 root             |

子脚本均可单独运行，不依赖 `start.sh`。完整参数表、执行流程与坑位清单见 [`Setup/README.md`](Setup/README.md)。

### 快速开始

```bash
# ① 从 1Password 拉 env（默认产出 vps.env，chmod 600）
curl -fsSL -o env.sh https://raw.githubusercontent.com/RexLee0929/VPS/main/Setup/env.sh
bash env.sh --token-file=/root/.config/op/token --vault=Infra --item=vps-env

# ② 先看一遍会做什么（强烈建议），确认无误后去掉 --dry-run 真跑
curl -fsSL -o start.sh https://raw.githubusercontent.com/RexLee0929/VPS/main/Setup/start.sh
bash start.sh --env=vps.env --prefix=home --ss-id=3 --vmess-id=4 --choice=6 --dry-run
```

- `--choice=6` = 装代理 + 改配置（最常用）；`--choice=1` 一把梭，且仅当给了 `--ssh-*` 参数时才带 SSH 步骤（避免只想装代理却重启一遍 sshd）
- 想连 SSH 一起初始化，加 `--ssh-port=2222 --ssh-root-login=no --ssh-password-auth=no --ssh-pubkey-file=/root/.ssh/id_ed25519.pub`
- DDNS 进 cron（`--mode=compact` 只输出一行，适合进日志）：

```cron
*/2 * * * * /root/Setup/ddns.sh --key "TOKEN" --domain "example.com" --prefix "home" --type A --proxy false --mode compact >> /root/ddns.log 2>&1
```

## ToolBox/ — 交互式运维工具箱

`toolbox.sh` v3.0.0（2026-10-16 重构版，3453 → 2132 行）：BBR、时区、swap、IPv4/IPv6 优先级、融合怪、FinalShell 增强、流媒体与游戏延迟检测、wget/curl/git、nano、screen、unzip/7zip/rar 批处理、Caddy、aapanel、哪吒 Agent、Aria2、soga / XrayR / ss-go / 极光面板。单文件、零依赖配置，下载即可运行。

**菜单编号与旧版完全一致**（系统 1-9 / 软件 1-12 / 科学上网 1-4），变化全在内部：修复 17 个功能性 bug、数据驱动菜单引擎、改系统文件前自动备份、`--dry-run` 全菜单预览。

一行跑（也可以先落盘 review 再跑）：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/RexLee0929/VPS/main/ToolBox/toolbox.sh)
```

常用开关：`--dry-run`（演练，只打印不落地）、`--yes`、`--no-color`、`--self-update`（自动升级）。完整菜单逐项说明、压缩包驱动与安全机制见 [`ToolBox/README.md`](ToolBox/README.md)；重构前后的问题清单与架构对比见 [`ToolBox/toolbox重构报告-20261016.html`](ToolBox/toolbox重构报告-20261016.html)。

## Script/ — 备份脚本

`backup.sh` v5.2：Docker Compose 项目备份 —— 停服务 → rsync 到临时目录 → 起服务 → pigz / zip 压缩，失败保留现场不清理。`-c no` 可当纯目录备份用。

```bash
curl -fsSL -o backup.sh https://raw.githubusercontent.com/RexLee0929/VPS/main/Script/backup.sh
bash backup.sh -b /home/SiteProxy       # compose 项目（自动 down/up）
bash backup.sh -b /data/static -c no    # 纯目录备份
```

常用参数：`-f` 输出目录（默认 `/home/Backup`）、`-z` 压缩格式（`tar.gz` / `zip`，zip 缺失自动回退）、`-d` 成功后是否清理临时目录、`-l` 日志文件。

## config/ — 配置模板

| 文件                              | 用途                                                         |
| --------------------------------- | ------------------------------------------------------------ |
| `env_vps.txt`                     | `vps.env` 键集模板：`cf_key` / `cf_email` / `domain1` / `domain2` / `v2board_webapi_*` / `nezha_*` / `ssh_*` / `pubkey_<名字>` |
| `soga.conf`                       | soga 总配置参考（webapi / db 双对接、DNS 策略、动态限速、redis） |
| `soga-ss.conf`、`soga-vmess.conf` | `proxy.sh --action=config` 实际拉取的 ss / vmess 实例配置    |
| `xrayr.yml`                       | XrayR 配置参考（NewV2board 面板对接）                        |
| `aria2.conf`                      | P3TERX aria2 配置（410 行注释版）                            |
| `conf.ini`                        | Cloudreve 配置                                               |
| `df`                              | FinalShell 增强：`df` 默认过滤 overlay 类型（docker 挂载路径），ToolBox 系统菜单 7 会装它 |

## 凭据纪律

> [!WARNING]
> 任何密钥都不要进本仓库、不要放 gist。GitHub Secret Scanning 扫到 secret gist → 通知 Cloudflare → API Token 被**自动吊销**。

- env 走 1Password：`Setup/env.sh` + `ops_` 开头的 Service Account token，一条安全笔记存完整 env
- 一台机器一个 Token；只放本机 `600` 权限文件，不进任何联网可读处
- 仓库里只放**空值模板**（如 `config/env_vps.txt`），抄回家自己填

## 注意事项

- **Cloudflare 橙云有端口白名单**：只放行 HTTP `80/8080/8880/2052/2082/2086/2095` + HTTPS `443/2053/2083/2087/2096/8443`；管理端口（如 5666/5667）开橙云必失败。`start.sh` 对 A/AAAA 记录固定传 `--proxy=false`，面板里手工开的橙云会被每轮覆盖。
- **soga 改完配置必须 `restart`**：`soga start` 对已在运行的实例是空操作，不重读 `soga.conf`；`proxy.sh` 已按 `restart` 实现。
- **SSH 有锁门风险**：改端口前先放行新端口，关密码登录前先确认公钥能登；`ssh.sh` 改前自动备份、改后 `sshd -t -f` 校验通过才重启。
- `Setup/README.md`、`ToolBox/README.md` 中少数快速开始命令仍是旧路径 `sh/...`（仓库 2026-10-16 已调整为 `Setup/`、`ToolBox/`），**以本页为准**。

---

本仓库脚本按原样提供，涉及第三方脚本（BBR、融合怪、哪吒、soga、XrayR 等）的版权与行为归各自上游，使用前请自行 review。欢迎 issue 交流。

*最后更新：2026-10-16*
