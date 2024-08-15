import re

def increment_number(match):
    number_str = match.group(2)  # 获取匹配到的数字字符串
    number = int(number_str)  # 转换为整数
    increment = 516  # 设置增加的位数
    new_number = number + increment  # 计算新的数字
    return f'第{new_number}章'  # 返回带有新的数字的替换结果

filename = r'C:\Users\lunto\Desktop\1.txt'   # 替换为实际的文件名
start_line = 1  # 指定起始行号
end_line = 20230  # 指定结束行号

with open(filename, 'r', encoding='utf-8') as file:
    lines = file.readlines()

for i, line in enumerate(lines):
    if start_line <= i+1 <= end_line:
        pattern = r'(第)(\d+)(章)'  # 匹配 "第" 后面的数字和 "章"
        replaced_line = re.sub(pattern, increment_number, line)
        lines[i] = replaced_line

with open(filename, 'w', encoding='utf-8') as file:
    file.writelines(lines)
