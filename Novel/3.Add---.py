import os
import re

# 指定要处理的目录
directory = 'C:/Users/lunto/Desktop/New'

success_files = []
fail_files = []
skipped_files = []
success_add_count = {}
fail_reasons = {}
skip_reasons = {}

# 遍历目录下的所有文件
for filename in os.listdir(directory):
    if filename.endswith('.txt'):
        file_path = os.path.join(directory, filename)

        # 读取文件内容
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                lines = file.readlines()

            # 添加分隔符和空行
            modified_lines = []
            add_count = 0
            skip_count = 0
            for i, line in enumerate(lines):
                modified_lines.append(line.rstrip())  # 移除行末尾的换行符
                match = re.search(r'第[一二两三四五六七八九十零百千]+[卷章回](?=\s)', line)
                if match:
                    # 检查第和卷/章/回之间的内容是否满足条件
                    content = re.search(r'第([一二两三四五六七八九十零百千]+)[卷章回]', match.group()).group(1)
                    if re.match(r'^[零一二三四五六七八九十百千]+$', content):
                        # 检查下一行是否已经是---
                        next_line_index = i + 2
                        if next_line_index < len(lines) and lines[next_line_index].strip() == '---':
                            skip_count += 1
                            continue
                        else:
                            modified_lines.append('')  # 添加空行
                            modified_lines.append('---')  # 添加分隔符
                            add_count += 1

            # 将修改后的内容写回文件
            with open(file_path, 'w', encoding='utf-8') as file:
                file.write('\n'.join(modified_lines))

            if add_count == 0 and skip_count > 0:
                skipped_files.append(filename)
                skip_reasons[filename] = f"已经添加过{skip_count}组组合了,本次运行没有补充"
            elif add_count > 0 and skip_count > 0:
                success_files.append(filename)
                success_add_count[filename] = f"已经添加过{skip_count}组组合了,本次运行补充了{add_count}组组合"
            elif add_count > 0 and skip_count == 0:
                success_files.append(filename)
                success_add_count[filename] = f"本次运行添加了{add_count}组组合"
        except Exception as e:
            fail_files.append(filename)
            fail_reasons[filename] = str(e)

print(f"本次运行共{len(success_files) + len(fail_files) + len(skipped_files)}个文件进行添加---,添加成功{len(success_files)}个文件,添加失败{len(fail_files)}个文件,跳过{len(skipped_files)}个文件")
print("添加成功的文件为:")
for file in success_files:
    print(f"{file}的添加情况为: {success_add_count[file]}")

print("添加失败的文件为:")
for file in fail_files:
    print(f"{file}添加失败的原因是: {fail_reasons[file]}")

print("跳过的文件为:")
for file in skipped_files:
    print(f"{file}跳过的原因是:{skip_reasons[file]}")
