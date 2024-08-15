import os
import re

def check_text_files(directory):
    matching_files = []
    non_matching_files = []
    total_files = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.txt'):
                total_files += 1
                file_path = os.path.join(root, file)
                result = contains_pattern(file_path)
                if result:
                    matching_files.append((file_path, result))
                else:
                    non_matching_files.append(file_path)
    return total_files, matching_files, non_matching_files

def contains_pattern(file_path):
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()
        sharp_count = content.count('# ')
        double_sharp_count = content.count('## ')
        if sharp_count >= 1 and double_sharp_count >= 1:
            return (sharp_count, double_sharp_count)
    return False

# 指定要检查的目录
directory = r'C:\Users\lunto\Desktop\New'  # 替换为实际的目录路径

# 检查文本文件是否满足条件
total_files, matching_files, non_matching_files = check_text_files(directory)

# 打印结果
print(f"本次检测了文件夹'{directory}'下的{total_files}个文件，其中满足'## '的数量大于等于1且'# '的数量大于等于1的文件有{len(matching_files)}个，不满足'## '的数量大于等于1且'# '的数量大于等于1的文件有{len(non_matching_files)}个")
if matching_files:
    print("满足条件的文件有:")
    for file, (sharp_count, double_sharp_count) in matching_files:
        print(f"{file}的第一行前面有一组'# ',卷号前面有{sharp_count - 1}组'# ',章节号前面有{double_sharp_count}组'## '")

if non_matching_files:
    print("不满足条件的文件有:")
    for file in non_matching_files:
        print(file)
