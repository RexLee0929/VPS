#!/bin/bash
# ===========================================================
# Docker Compose 通用备份脚本 (v6.0)
#
# 相对 v5.2 的关键改动：
#   1. 默认“跟随符号链接”（rsync -L），备份里存真实文件而不是链接
#      可用 -L no 关闭（需要保留链接结构的场景）
#   2. 无论在哪一步失败，退出时都会把 docker compose 重新拉起来（trap）
#   3. 修复 -z zip 时额外生成一个 tar.gz 并误报“不支持的格式”的 bug
#   4. 压缩后做一次归档完整性校验（tar -tzf / unzip -t）
#   5. 新增 -k 保留天数（0 = 不清理，保持原行为）
#
# 用法：
#   bash backup.sh -b /home/Config -f /home/Backup/NetCup
#   bash backup.sh -b /home/Config -f /home/Backup/NetCup -L no   # 保留链接
#   bash backup.sh -b /data/static -c no -k 30                    # 纯目录 + 留 30 天
#
# 参数：
#   -b <路径>        必填：被备份路径
#   -p <临时路径>    选填：默认 /home/Backup/temp
#   -f <输出目录>    选填：默认 /home/Backup
#   -z <格式>        选填：tar.gz | zip，默认 tar.gz
#   -d <yes|no>      选填：成功后是否清理临时目录，默认 yes
#   -l <日志文件>    选填：默认 /home/log/Backup.log
#   -c <yes|no>      选填：是否视为 docker compose 项目，默认 yes
#   -L <yes|no>      选填：是否跟随符号链接（存实体），默认 yes
#   -k <天数>        选填：删除多少天前的旧备份，默认 0（不清理）
# ===========================================================

set -uo pipefail

# --- 默认参数 ---
BACKUP_TARGET=""
TEMP_DIR="/home/Backup/temp"
BACKUP_DIR="/home/Backup"
ZIP_TYPE="tar.gz"
DELETE_TEMP="yes"
LOG_FILE="/home/log/Backup.log"
COMPOSE_MODE="yes"
FOLLOW_LINKS="yes"
KEEP_DAYS=0

# --- 解析参数 ---
while getopts ":b:p:f:z:d:l:c:L:k:" opt; do
  case "$opt" in
    b) BACKUP_TARGET="$OPTARG" ;;
    p) TEMP_DIR="$OPTARG" ;;
    f) BACKUP_DIR="$OPTARG" ;;
    z) ZIP_TYPE="$OPTARG" ;;
    d) DELETE_TEMP="$OPTARG" ;;
    l) LOG_FILE="$OPTARG" ;;
    c) COMPOSE_MODE="$OPTARG" ;;
    L) FOLLOW_LINKS="$OPTARG" ;;
    k) KEEP_DAYS="$OPTARG" ;;
    *) echo "[错误] 无效参数: -$OPTARG" >&2; exit 2 ;;
  esac
done

# --- 路径归一化：脚本中途会 cd，相对路径必须先转绝对 ---
ORIG_PWD="$(pwd)"
to_abs() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$ORIG_PWD" "$1" ;;
  esac
}
TEMP_DIR="$(to_abs "$TEMP_DIR")"
BACKUP_DIR="$(to_abs "$BACKUP_DIR")"
LOG_FILE="$(to_abs "$LOG_FILE")"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# --- 日志函数 ---
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

fail() {
  log "[失败] $1"
  exit 1
}

to_lower() {
  echo "$1" | tr 'A-Z' 'a-z'
}

# --- 基本校验 ---
[ -z "${BACKUP_TARGET}" ] && fail "未指定被备份路径，请使用 -b 参数"
[ ! -d "${BACKUP_TARGET}" ] && fail "被备份路径不存在：${BACKUP_TARGET}"

BACKUP_TARGET="${BACKUP_TARGET%/}"
[ -z "${BACKUP_TARGET}" ] && fail "-b 不能是根目录 /"

# 归一化为绝对路径（同时去掉结尾斜杠）
if ! BACKUP_TARGET="$(cd "$BACKUP_TARGET" && pwd)"; then
  fail "无法解析被备份路径：${BACKUP_TARGET}"
fi

COMPOSE_MODE="$(to_lower "${COMPOSE_MODE}")"
FOLLOW_LINKS="$(to_lower "${FOLLOW_LINKS}")"
case "${COMPOSE_MODE}" in yes|no) ;; *) fail "-c 仅允许 yes 或 no（当前：${COMPOSE_MODE}）" ;; esac
case "${FOLLOW_LINKS}" in yes|no) ;; *) fail "-L 仅允许 yes 或 no（当前：${FOLLOW_LINKS}）" ;; esac

PROJECT_NAME="$(basename "$BACKUP_TARGET")"
DATE_STR="$(date '+%Y%m%d')"
ARCHIVE_BASENAME="${DATE_STR} ${PROJECT_NAME}"
TEMP_PROJECT_DIR="${TEMP_DIR%/}/${PROJECT_NAME}"
FINAL_EXT=""
FINAL_PATH=""
COMPOSE_STOPPED=0

# --- 兜底：不管从哪一步退出，只要停过 compose 就拉起来 ---
compose_restore() {
  rc=$?
  if [ "${COMPOSE_STOPPED}" = "1" ]; then
    log "[恢复] 脚本退出（退出码 ${rc}），重新启动 docker compose..."
    if cd "${BACKUP_TARGET}" 2>/dev/null && docker compose up -d >> "${LOG_FILE}" 2>&1; then
      log "[恢复] docker compose 已恢复运行"
      COMPOSE_STOPPED=0
    else
      log "[严重] docker compose 恢复失败！请手动执行：cd ${BACKUP_TARGET} && docker compose up -d"
    fi
  fi
}
trap compose_restore EXIT

# --- Compose 文件探测 ---
HAS_COMPOSE_FILE="no"
if [ "${COMPOSE_MODE}" = "yes" ]; then
  if [ -f "${BACKUP_TARGET}/docker-compose.yml" ] || [ -f "${BACKUP_TARGET}/docker-compose.yaml" ] || \
     [ -f "${BACKUP_TARGET}/compose.yml" ] || [ -f "${BACKUP_TARGET}/compose.yaml" ]; then
    HAS_COMPOSE_FILE="yes"
  else
    log "[警告] 未检测到 docker compose 文件，自动降级为非 compose 模式（仅复制与压缩）"
    COMPOSE_MODE="no"
  fi
fi

# --- 输出概要 ---
log "====================================="
log "📦 项目备份开始"
log "📁 被备份路径：${BACKUP_TARGET}"
log "🗂 项目名称：${PROJECT_NAME}"
log "📆 日期：${DATE_STR}"
log "📍 临时目录：${TEMP_PROJECT_DIR}"
log "📂 备份输出目录：${BACKUP_DIR}"
log "📚 期望压缩格式：${ZIP_TYPE}"
log "🔗 跟随符号链接：${FOLLOW_LINKS}"
log "🧹 成功后清理临时：${DELETE_TEMP}"
log "🐳 作为 compose 项目：${COMPOSE_MODE}"
[ "${KEEP_DAYS}" -gt 0 ] 2>/dev/null && log "🗑 旧备份保留天数：${KEEP_DAYS}"
log "🪵 日志文件：${LOG_FILE}"
log "====================================="

# --- 准备目录 + 空间提示 ---
mkdir -p "${TEMP_PROJECT_DIR}" || fail "创建临时目录失败：${TEMP_PROJECT_DIR}"
mkdir -p "${BACKUP_DIR}" || fail "创建备份输出目录失败：${BACKUP_DIR}"

AVAIL_KB="$(df -Pk "${TEMP_DIR%/}" 2>/dev/null | awk 'NR==2{print $4}')"
if [ -n "${AVAIL_KB}" ]; then
  log "💽 临时目录可用空间：$((AVAIL_KB / 1024)) MB"
  if [ "${AVAIL_KB}" -lt 1048576 ]; then
    log "[警告] 可用空间不足 1GB，rsync 复制可能失败"
  fi
fi

# --- 符号链接盘点 ---
# 三类要分开，判断错了就会误报或漏备：
#   内部链接   —— 目标在备份集内，随包一起走，恢复后有效
#   外部链接   —— 宿主机上真实存在但在备份集外（如 /etc/letsencrypt/live/x），必须解引用
#   容器内路径 —— 目标形如 /data/...，宿主机没有但在容器里有效（.dovecot.sieve 就是这类）
log "[0/4] 盘点符号链接..."
n_int=0; n_ext=0; n_box=0; n_bad=0
while IFS= read -r -d '' l; do
  raw="$(readlink "$l")"
  tgt="$(readlink -f "$l" 2>/dev/null || true)"
  if [ -n "$tgt" ]; then
    if [ "${tgt#"${BACKUP_TARGET}/"}" != "$tgt" ]; then
      n_int=$((n_int + 1))
    else
      n_ext=$((n_ext + 1))
      log "[提示] 外部链接（按实体文件备份）：${l} -> ${tgt}"
    fi
  elif [ "${raw#/}" != "$raw" ] && [ -e "${BACKUP_TARGET}${raw}" ]; then
    n_box=$((n_box + 1))
  else
    n_bad=$((n_bad + 1))
    log "[警告] 悬空链接（宿主机与容器内都找不到目标）：${l} -> ${raw}"
  fi
done < <(find "${BACKUP_TARGET}" -type l -print0 2>/dev/null)
log "🔗 链接统计：内部 ${n_int} / 外部 ${n_ext} / 容器内路径 ${n_box} / 悬空 ${n_bad}"
if [ "${n_box}" -gt 0 ]; then
  log "ℹ️ 容器内路径链接是 Poste.io 这类容器的正常现象，不是错误；它们指向的文件已单独备份"
fi

# --- 停止 compose ---
if [ "${COMPOSE_MODE}" = "yes" ]; then
  cd "${BACKUP_TARGET}" || fail "无法进入目录：${BACKUP_TARGET}"
  log "[1/4] 停止 docker compose..."
  if docker compose down >> "${LOG_FILE}" 2>&1; then
    COMPOSE_STOPPED=1
  else
    fail "docker compose down 执行失败，请检查日志：${LOG_FILE}"
  fi
else
  log "[1/4] 非 compose 模式，跳过 docker 停止步骤"
fi

# --- 复制（关键：跟随符号链接）---
if [ "${FOLLOW_LINKS}" = "yes" ]; then
  RSYNC_LINK_OPT="-L"
  log "[2/4] 复制项目文件到临时目录（-L 跟随符号链接，存真实文件）..."
else
  RSYNC_LINK_OPT=""
  log "[2/4] 复制项目文件到临时目录（保留符号链接，外部链接将不可用）..."
fi

rsync -a ${RSYNC_LINK_OPT} --delete "${BACKUP_TARGET}/" "${TEMP_PROJECT_DIR}/" >> "${LOG_FILE}" 2>&1
rsync_rc=$?
case "${rsync_rc}" in
  0)
    log "✅ rsync 完成"
    ;;
  23)
    log "[说明] rsync 跳过部分条目（退出码 23），通常是容器内路径链接；按“部分成功”继续"
    ;;
  *)
    fail "rsync 复制失败（退出码 ${rsync_rc}），请检查权限与磁盘空间"
    ;;
esac

# --- 把 -L 跳过的「容器内路径」链接按原样补回临时副本 ---
# 这些链接在容器里是有效的（/data/... = 宿主机上的 data/...），
# 保留它们，恢复后 Dovecot 的过滤器状态不用重建。
if [ "${FOLLOW_LINKS}" = "yes" ] && [ "${n_box}" -gt 0 ]; then
  log "[修复] 补回容器内路径链接..."
  n_fix=0
  while IFS= read -r -d '' src; do
    raw="$(readlink "$src")"
    case "$raw" in /*) ;; *) continue ;; esac
    [ -e "$raw" ] && continue
    [ -e "${BACKUP_TARGET}${raw}" ] || continue
    rel="${src#"${BACKUP_TARGET}"/}"
    dst="${TEMP_PROJECT_DIR}/${rel}"
    if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
      mkdir -p "$(dirname "$dst")" && ln -s "$raw" "$dst" && n_fix=$((n_fix + 1))
    fi
  done < <(find "${BACKUP_TARGET}" -type l -print0 2>/dev/null)
  log "🔗 已补回 ${n_fix} 个链接（容器内恢复后有效，不占额外空间）"
fi

# --- 启动 compose ---
if [ "${COMPOSE_MODE}" = "yes" ]; then
  log "[3/4] 启动 docker compose..."
  if cd "${BACKUP_TARGET}" && docker compose up -d >> "${LOG_FILE}" 2>&1; then
    COMPOSE_STOPPED=0
    log "✅ compose 已启动"
  else
    log "[错误] compose 启动失败，退出时会再试一次"
  fi
else
  log "[3/4] 非 compose 模式，跳过 docker 启动步骤"
fi

# --- 压缩 ---
log "[4/4] 打包压缩..."
cd "${TEMP_DIR%/}" || fail "无法进入临时父目录：${TEMP_DIR}"

compress_ok=0

try_tar_gz() {
  FINAL_EXT="tar.gz"
  FINAL_PATH="${BACKUP_DIR%/}/${ARCHIVE_BASENAME}.tar.gz"
  if command -v pigz >/dev/null 2>&1; then
    tar -I pigz -cf "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1 && compress_ok=1
  else
    tar -czf "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1 && compress_ok=1
  fi
}

case "$(to_lower "${ZIP_TYPE}")" in
  zip)
    if command -v zip >/dev/null 2>&1; then
      FINAL_EXT="zip"
      FINAL_PATH="${BACKUP_DIR%/}/${ARCHIVE_BASENAME}.zip"
      zip -r "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1 && compress_ok=1
      if [ ${compress_ok} -ne 1 ]; then
        log "[警告] zip 压缩失败，回退为 tar.gz"
        rm -f "${FINAL_PATH}"
      fi
    else
      log "[提示] 系统未安装 zip，改用 tar.gz"
    fi
    ;;
  tar.gz)
    try_tar_gz
    ;;
  *)
    log "[警告] 不支持的压缩格式：${ZIP_TYPE}，改用 tar.gz"
    try_tar_gz
    ;;
esac

# 任何情况下没成功，统一回退 tar.gz（zip 缺失或压缩失败都会走到这里）
if [ ${compress_ok} -ne 1 ] && [ "${FINAL_EXT}" != "tar.gz" ]; then
  try_tar_gz
fi

if [ ${compress_ok} -ne 1 ]; then
  log "[错误] 压缩失败，备份未生成。临时目录已保留：${TEMP_PROJECT_DIR}"
  exit 1
fi

if [ ! -s "${FINAL_PATH}" ]; then
  log "[错误] 归档文件为空：${FINAL_PATH}。临时目录已保留：${TEMP_PROJECT_DIR}"
  exit 1
fi

# --- 归档完整性校验 ---
log "🔍 校验归档完整性（会读一遍整个压缩包）..."
verify_ok=0
case "${FINAL_EXT}" in
  zip)
    if command -v unzip >/dev/null 2>&1; then
      unzip -t "${FINAL_PATH}" >> "${LOG_FILE}" 2>&1 && verify_ok=1
    else
      log "[跳过] 未安装 unzip，无法校验 zip"
      verify_ok=1
    fi
    ;;
  *)
    tar -tzf "${FINAL_PATH}" >/dev/null 2>&1 && verify_ok=1
    ;;
esac

if [ ${verify_ok} -ne 1 ]; then
  log "[错误] 归档校验失败，文件可能已损坏：${FINAL_PATH}。临时目录已保留：${TEMP_PROJECT_DIR}"
  exit 1
fi

# --- 归档内链接统计 ---
if [ "${FINAL_EXT}" = "tar.gz" ]; then
  link_left="$(tar -tvzf "${FINAL_PATH}" 2>/dev/null | grep -c '^l' || true)"
  if [ "${FOLLOW_LINKS}" = "yes" ]; then
    log "🔗 归档内符号链接：${link_left} 个（应为容器内路径链接，数量≈上面“补回”数）"
  else
    log "🔗 归档内符号链接：${link_left} 个（-L no 模式：全部按链接保留）"
  fi
fi

# --- 清理临时 ---
if [ "${DELETE_TEMP}" = "yes" ]; then
  log "[清理] 删除临时目录：${TEMP_PROJECT_DIR}"
  rm -rf "${TEMP_PROJECT_DIR}" || log "[警告] 临时目录删除失败：${TEMP_PROJECT_DIR}"
else
  log "[保留] 临时目录已保留：${TEMP_PROJECT_DIR}"
fi

# --- 旧备份清理（可选）---
if [ "${KEEP_DAYS}" -gt 0 ] 2>/dev/null; then
  log "[保留策略] 清理 ${KEEP_DAYS} 天前的备份..."
  find "${BACKUP_DIR}" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.zip' \) \
       -mtime "+${KEEP_DAYS}" -print -delete >> "${LOG_FILE}" 2>&1 || log "[警告] 旧备份清理出错"
fi

log "-------------------------------------"
log "✅ 备份完成：${FINAL_PATH}"
log "📚 实际压缩格式：${FINAL_EXT}"
log "📏 归档大小：$(du -h "${FINAL_PATH}" 2>/dev/null | awk '{print $1}')"
log "====================================="
