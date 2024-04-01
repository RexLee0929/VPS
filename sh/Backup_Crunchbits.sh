#!/bin/bash

# 获取当前时间，格式如 2023092900
current_time=$(date +"%Y%m%d%H%M")

# 指定 caddy 源文件和备份目录
src_file_caddy="/etc/caddy/Caddyfile"
backup_dir_caddy="/Backup/caddy"

# 指定 supervisor 源目录和备份目录
src_dir_supervisor="/etc/supervisor/conf.d/"
backup_dir_supervisor="/Backup/supervisor"

# 创建 caddy 和 supervisor 备份目录，如果不存在
mkdir -p "$backup_dir_caddy"
mkdir -p "$backup_dir_supervisor"

# 使用当前时间作为前缀，复制 caddy 文件到备份目录
cp "$src_file_caddy" "$backup_dir_caddy/${current_time}_Caddyfile"

# 使用当前时间作为前缀，复制 supervisor 文件到备份目录
for file in "$src_dir_supervisor"/*; do
  filename=$(basename -- "$file")
  cp "$file" "$backup_dir_supervisor/${current_time}_${filename}"
done
