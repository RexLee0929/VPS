import os
import chardet

def get_encoding(file_path):
    with open(file_path, 'rb') as file:
        result = chardet.detect(file.read())
    return result['encoding']

def find_files_encodings(directory):
    utf8_files = []
    non_utf8_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.txt'):
                file_path = os.path.join(root, file)
                encoding = get_encoding(file_path)
                if encoding == 'utf-8':
                    utf8_files.append(file_path)
                else:
                    non_utf8_files.append((file_path, encoding))
    return utf8_files, non_utf8_files

# 指定要搜索的目录
directory = r'C:\Users\lunto\Desktop\New'  # 替换为实际的目录路径

# 获取所有文件的编码
utf8_files, non_utf8_files = find_files_encodings(directory)

# 打印结果
print(f'本次检测了文件夹"{directory}"下的{len(utf8_files) + len(non_utf8_files)}个文件,其中{len(utf8_files)}个文件是utf8编码,其中{len(non_utf8_files)}个文件不是utf8编码')

print("以下文件的编码是utf8：")
for file in utf8_files:
    print(f"{file}的编码是utf8")

print("以下文件的编码不是utf8：")
for file, encoding in non_utf8_files:
    print(f"{file}的编码是{encoding}")
