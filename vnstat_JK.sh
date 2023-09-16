#!/bin/bash

# 输出标题行和分隔线
printf "| %-12s | %-20s | %-13s | %-22s | %-13s | %-23s |\n" "interfaces" "Database updated" "daily-total" "daily-total-estimated" "monthly-total" "monthly-total-estimated"
echo "--------------------------------------------------------------------------------------------------------------------------"

# 获取所有接口列表，并筛选出虚拟以太网（veth）接口和 eth0
for line in $(vnstat --iflist | grep -oE 'veth[0-9a-f]+|eth0'); do
    # 对每个接口运行 vnstat 并提取所需信息
    vnstat_output=$(vnstat -i "$line")
    db_updated=$(echo "$vnstat_output" | grep 'Database updated:' | awk '{print $3 " " $4 " " $5}')

    # 使用指定的行和列范围来提取数据
    daily_total=$(echo "$vnstat_output" | awk 'NR==17' | cut -c45-57)
    daily_total_estimated=$(echo "$vnstat_output" | awk 'NR==19' | cut -c45-57)
    monthly_total=$(echo "$vnstat_output" | awk 'NR==10' | cut -c45-57)
    monthly_total_estimated=$(echo "$vnstat_output" | awk 'NR==12' | cut -c45-57)
    
    # 输出提取的信息，使用 printf 对齐各列
    printf "| %-12s | %-20s | %-13s | %-22s | %-13s | %-23s |\n" "$line" "$db_updated" "$daily_total" "$daily_total_estimated" "$monthly_total" "$monthly_total_estimated"
done
