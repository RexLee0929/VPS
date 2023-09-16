# 提取数值和单位
limit_value=$(echo $limit | tr -d -c 0-9)
limit_unit=$(echo $limit | tr -d -c a-zA-Z)

# 将限制转换为 MiB
case "$limit_unit" in
  "KiB") limit_value=$((limit_value / 1024)) ;;
  "MiB") limit_value=$limit_value ;;
  "GiB") limit_value=$((limit_value * 1024)) ;;
  "TiB") limit_value=$((limit_value * 1024 * 1024)) ;;
  *) echo "Invalid unit in limit. Exiting."; exit 1 ;;
esac

# 添加一个变量来存储被“禁用通知”的接口名称
disabled_notify_interfaces="eth0"  # 你可以在这里添加更多的接口名称,以空格隔开

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

    # 提取月度流量数据，并转换为 MiB
    monthly_total_raw=$(echo "$monthly_total" | tr -d ' ')
    monthly_total_mib=0
    if [[ "$monthly_total_raw" == *GiB ]]; then
        monthly_total_mib=$(echo "$monthly_total_raw" | sed 's/GiB//' | awk '{print int($1 * 1024)}')
    elif [[ "$monthly_total_raw" == *MiB ]]; then
        monthly_total_mib=$(echo "$monthly_total_raw" | sed 's/MiB//' | awk '{print int($1)}')
    elif [[ "$monthly_total_raw" == *KiB ]]; then
        monthly_total_mib=$(echo "$monthly_total_raw" | sed 's/KiB//' | awk '{print int($1 / 1024)}')
    fi
    
if [ "$monthly_total_mib" -gt "$limit_value" ]; then  # 注意这里使用了 limit_value 而不是 limit
  # 检查接口是否在“禁用通知”列表中
  if [[ $disabled_notify_interfaces != *$line* ]]; then
    # 流量超限，发送通知给 Telegram Bot
    message="流量预警%0A接口: $line%0A每月限制流量: ${limit}%0A当月使用流量: $monthly_total_raw%0A已经超出限制请注意"
    curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage?chat_id=$USER_ID&text=$message"
  fi
fi
done
