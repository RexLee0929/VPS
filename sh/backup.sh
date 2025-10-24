#!/bin/bash
# ===========================================================
# Docker Compose 通用备份脚本 (v5.1)
# 用法示例：
#   bash /home/backup.sh -b /home/SiteProxy
#   bash /home/backup.sh -b /srv/docker/emby -f /mnt/backup -z tar.gz -d n -l /var/log/docker_backup.log
# 参数：
#   -b <被备份路径>        必填：要备份的 Docker 项目目录
#   -p <临时路径>          选填：默认 /home/Backup/temp/
#   -f <备份输出目录>      选填：默认 /home/Backup/
#   -z <zip|tar.gz>        选填：默认 tar.gz（自动检测可用性并回退）
#   -d <y|n>               选填：成功后是否清理临时目录，默认 y
#   -l <日志文件路径>      选填：默认 /home/log/Backup.log
# ===========================================================

set -uo pipefail

# --- 默认参数 ---
BACKUP_TARGET=""
TEMP_DIR="/home/Backup/temp"
BACKUP_DIR="/home/Backup"
ZIP_TYPE="tar.gz"
DELETE_TEMP="y"
LOG_FILE="/home/log/Backup.log"

# --- 解析参数 ---
while getopts ":b:p:f:z:d:l:" opt; do
  case "$opt" in
    b) BACKUP_TARGET="$OPTARG" ;;
    p) TEMP_DIR="$OPTARG" ;;
    f) BACKUP_DIR="$OPTARG" ;;
    z) ZIP_TYPE="$OPTARG" ;;
    d) DELETE_TEMP="$OPTARG" ;;
    l) LOG_FILE="$OPTARG" ;;
    *) echo "[错误] 无效参数: -$OPTARG" >&2; exit 2 ;;
  esac
done

# --- 日志函数 ---
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  echo "$msg" >> "$LOG_FILE"
}

fail() {
  log "[失败] $1"
  exit 1
}

# --- 基本校验 ---
[ -z "${BACKUP_TARGET}" ] && fail "未指定被备份路径，请使用 -b 参数"
[ ! -d "${BACKUP_TARGET}" ] && fail "被备份路径不存在：${BACKUP_TARGET}"

PROJECT_NAME="$(basename "$BACKUP_TARGET")"
DATE_STR="$(date '+%Y%m%d')"
ARCHIVE_BASENAME="${DATE_STR} ${PROJECT_NAME}"
TEMP_PROJECT_DIR="${TEMP_DIR%/}/${PROJECT_NAME}"
FINAL_EXT=""         # 实际使用的扩展名（zip 或 tar.gz）
FINAL_PATH=""        # 实际生成的压缩文件完整路径

# --- 输出概要 ---
log "====================================="
log "📦 Docker Compose 项目备份开始"
log "📁 被备份路径：${BACKUP_TARGET}"
log "🗂 项目名称：${PROJECT_NAME}"
log "📆 日期：${DATE_STR}"
log "📍 临时目录：${TEMP_PROJECT_DIR}"
log "📂 备份文件路径：${BACKUP_DIR}"
log "📚 期望压缩格式：${ZIP_TYPE}"
log "🧹 成功后清理临时：${DELETE_TEMP}"
log "🪵 日志文件：${LOG_FILE}"
log "====================================="

# --- 准备目录 ---
mkdir -p "${TEMP_PROJECT_DIR}" || fail "创建临时目录失败：${TEMP_PROJECT_DIR}"
mkdir -p "${BACKUP_DIR}" || fail "创建备份输出目录失败：${BACKUP_DIR}"

# --- 停止 Docker Compose ---
cd "${BACKUP_TARGET}" || fail "无法进入目录：${BACKUP_TARGET}"
log "[1/4] 停止 docker compose..."
if ! docker compose down >> "${LOG_FILE}" 2>&1; then
  fail "docker compose down 执行失败，请检查日志：${LOG_FILE}"
fi

# --- 复制项目到临时目录 ---
log "[2/4] 复制项目文件到临时目录..."
if ! rsync -a --delete "${BACKUP_TARGET}/" "${TEMP_PROJECT_DIR}/" >> "${LOG_FILE}" 2>&1; then
  fail "rsync 复制失败，请检查权限与磁盘空间"
fi

# --- 启动 Docker Compose ---
log "[3/4] 启动 docker compose..."
if ! docker compose up -d >> "${LOG_FILE}" 2>&1; then
  fail "docker compose up -d 执行失败，请检查日志：${LOG_FILE}"
fi

# --- 压缩 ---
log "[4/4] 打包压缩..."
cd "${TEMP_DIR}" || fail "无法进入临时父目录：${TEMP_DIR}"

compress_ok=0
case "${ZIP_TYPE}" in
  zip)
    if command -v zip >/dev/null 2>&1; then
      FINAL_EXT="zip"
      FINAL_PATH="${BACKUP_DIR%/}/${ARCHIVE_BASENAME}.zip"
      if zip -r "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1; then
        compress_ok=1
      else
        log "[警告] zip 压缩失败，将尝试回退为 tar.gz"
      fi
    else
      log "[警告] 系统未安装 zip，自动回退为 tar.gz"
    fi
    ;;&  # 继续尝试 tar.gz 作为回退
  tar.gz)
    if [ ${compress_ok} -eq 0 ]; then
      FINAL_EXT="tar.gz"
      FINAL_PATH="${BACKUP_DIR%/}/${ARCHIVE_BASENAME}.tar.gz"
      if command -v pigz >/dev/null 2>&1; then
        # pigz 并行压缩更快
        if tar -I pigz -cf "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1; then
          compress_ok=1
        fi
      else
        if tar -czf "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1; then
          compress_ok=1
        fi
      fi
    fi
    ;;
  *)
    log "[警告] 不支持的压缩格式：${ZIP_TYPE}，自动采用 tar.gz"
    FINAL_EXT="tar.gz"
    FINAL_PATH="${BACKUP_DIR%/}/${ARCHIVE_BASENAME}.tar.gz"
    if command -v pigz >/dev/null 2>&1; then
      tar -I pigz -cf "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1 && compress_ok=1
    else
      tar -czf "${FINAL_PATH}" "${PROJECT_NAME}" >> "${LOG_FILE}" 2>&1 && compress_ok=1
    fi
    ;;
esac

# --- 压缩结果校验 ---
if [ ${compress_ok} -ne 1 ] || [ ! -s "${FINAL_PATH}" ]; then
  log "[错误] 压缩失败，备份未生成。临时目录已保留：${TEMP_PROJECT_DIR}"
  exit 1
fi

# --- 清理临时（仅成功后按需清理） ---
if [ "${DELETE_TEMP}" = "y" ]; then
  log "[清理] 删除临时目录：${TEMP_PROJECT_DIR}"
  rm -rf "${TEMP_PROJECT_DIR}" || log "[警告] 临时目录删除失败：${TEMP_PROJECT_DIR}"
else
  log "[保留] 临时目录已保留：${TEMP_PROJECT_DIR}"
fi

log "-------------------------------------"
log "✅ 备份完成：${FINAL_PATH}"
log "📚 实际压缩格式：${FINAL_EXT}"
log "====================================="
