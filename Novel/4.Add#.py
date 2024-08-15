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

            # 处理第一行
            add_count_0 = 0
            if lines:
                if not lines[0].startswith('# '):
                    lines[0] = '# ' + lines[0].lstrip()
                    add_count_0 += 1

            # 添加# 和 ##
            modified_lines = []
            add_count_1 = 0
            add_count_2 = 0
            skip_count_1 = 0
            skip_count_2 = 0
            for line in lines:
                if re.match(r'^# 第[一二两三四五六七八九十零百千]+卷(?=\s)', line):
                    skip_count_1 += 1
                    modified_lines.append(line.rstrip())
                elif re.match(r'^第[一二两三四五六七八九十零百千]+卷(?=\s)', line):
                    add_count_1 += 1
                    modified_lines.append('# ' + line.lstrip())
                elif re.match(r'^## 第[一二两三四五六七八九十零百千]+[章回](?=\s)', line):
                    skip_count_2 += 1
                    modified_lines.append(line.rstrip())
                elif re.match(r'^第[一二两三四五六七八九十零百千]+[章回](?=\s)', line):
                    add_count_2 += 1
                    modified_lines.append('## ' + line.lstrip())
                else:
                    modified_lines.append(line.rstrip())

            # 将修改后的内容写回文件
            with open(file_path, 'w', encoding='utf-8') as file:
                file.write('\n'.join(modified_lines))

            if add_count_0 == 0 and add_count_1 == 0 and add_count_2 == 0 and (skip_count_1 > 0 or skip_count_2 > 0):
                skipped_files.append(filename)
                skip_reasons[filename] = f"已经添加过了,并且不需要补充"
            elif add_count_0 > 0 or add_count_1 > 0 or add_count_2 > 0:
                success_files.append(filename)
                success_add_count[filename] = f"第一行前面添加了{add_count_0}组'# ',卷号前面补充了{add_count_1}组'# ',章节前面补充了{add_count_2}组'## '"
        except Exception as e:
            fail_files.append(filename)
            fail_reasons[filename] = str(e)

print(f"本次运行共{len(success_files) + len(fail_files) + len(skipped_files)}个文件进行添加'# '和'## ',添加成功{len(success_files)}个文件,添加失败{len(fail_files)}个文件,跳过添加{len(skipped_files)}个文件")
print("添加成功的文件为:")
for file in success_files:
    print(f"{file} {success_add_count[file]}")
print("添加失败的文件为:")
for file in fail_files:
    print(f"{file}添加失败的原因是: {fail_reasons[file]}")
print("跳过的文件为:")
for file in skipped_files:
    print(f"{file}跳过的原因是:{skip_reasons[file]}")
