#!/bin/bash

# 获取当前时间，格式如 2023092900
current_time=$(date +"%Y%m%d%H%M")

# 指定源文件和备份目录
src_file="/etc/caddy/Caddyfile"
backup_dir="/Backup/caddy"

# 创建备份目录，如果不存在
mkdir -p "$backup_dir"

# 使用当前时间作为前缀，复制文件到备份目录
cp "$src_file" "$backup_dir/${current_time}_Caddyfile"
