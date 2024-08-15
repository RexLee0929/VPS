import os
import shutil
import chardet

def get_encoding(file_path):
    with open(file_path, 'rb') as file:
        result = chardet.detect(file.read())
    return result['encoding']

def find_and_move_non_utf8_files(directory):
    non_utf8_dir = os.path.join(directory, "No-utf8")
    if not os.path.exists(non_utf8_dir):
        os.makedirs(non_utf8_dir)

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.txt'):
                file_path = os.path.join(root, file)
                encoding = get_encoding(file_path)
                if encoding != 'utf-8':
                    new_path = os.path.join(non_utf8_dir, file)
                    shutil.move(file_path, new_path)
                    print(f"Moved {file_path} to {new_path}")

# 指定要搜索的目录
directory = r'C:\Users\lunto\Desktop\New'  # 替换为实际的目录路径

# 查找并移动所有非UTF-8编码的文件
find_and_move_non_utf8_files(directory)
