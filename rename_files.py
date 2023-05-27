import os
import sys
import re


def clean_filename(filename):
    """
    清洗文件名
    """
    # 去除括号
    filename = re.sub(r'[()（）【】〔〕]', '', filename)
    # 去除cosor.top
    filename = filename.replace('cosor.top', '')
    # 去除首尾空格
    filename = filename.strip()
    # 将多个空格替换为单个空格
    filename = ' '.join(filename.split())
    # 将 - + _ 替换为空格
    filename = re.sub(r'[-+_]', ' ', filename)
    return filename


def rename_files(dir_path, is_preview):
    """
    重命名指定目录下的所有文件
    """
    # 创建日志文件
    log_path = '/DISK/renametest.log' if is_preview else '/DISK/rename.log'
    with open(log_path, 'w', encoding='utf-8') as f:
        # 遍历指定目录下的所有文件
        for root, dirs, files in os.walk(dir_path):
            for file in files:
                # 获取文件的绝对路径
                abs_file_path = os.path.join(root, file)
                # 获取文件名和拓展名
                filename, ext = os.path.splitext(file)
                # 将拓展名转换为小写
                ext = ext.lower()
                # 对文件名进行清洗
                new_filename = clean_filename(filename)
                # 如果文件名被修改，才进行重命名操作
                if new_filename != filename:
                    # 判断是否有数字编号
                    match_obj = re.match(r'^\D*(\d+)\D*$', new_filename)
                    if match_obj:
                        # 获取数字编号
                        num = match_obj.group(1)
                        # 根据数字编号的位数进行格式化
                        if len(num) < 3:
                            new_num = num.rjust(3, '0')
                        elif num.startswith('0'):
                            new_num = num.lstrip('0')
                            new_num = new_num.rjust(len(num), '0')
                        else:
                            new_num = num
                        # 替换数字编号
                        new_filename = new_filename.replace(num, new_num)
                    # 判断文件名是否合法
                    if not re.match(r'^[^\s][\w\s]*[^\s]$', new_filename):
                        print(f"非法文件名: {new_filename}")
                        f.write(f"非法文件名: {new_filename}\n")
                        continue
                    # 构建新文件名
                    new_name = os.path.join(root, new_filename + ext)
                    # 输出重命名前后的文件名
                    old_name = os.path.join(root, file)
                    print(f"OldName: {old_name} --> NewName: {new_name}")
                    f.write(f"OldName: {old_name} --> NewName: {new_name}\n")
                    # 预览模式不进行重命名操作
                    if is_preview:
                        continue
                    # 重命名文件
                    os.rename(abs_file_path, new_name)


if __name__ == '__main__':
    # 获取运行脚本时传递的参数
    if len(sys.argv) < 2:
        print("Usage: python rename_files.py <dir>")
    else:
        dir_path = sys.argv[1]
        is_preview = '-p' in sys.argv
        rename_files(dir_path, is_preview)

