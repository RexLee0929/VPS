import os

# 指定要处理的目录
directory = 'C:/Users/lunto/Desktop/New'  # 替换为实际的目录路径

# 遍历目录下的所有文件
for filename in os.listdir(directory):
    if filename.endswith('.txt'):
        file_path = os.path.join(directory, filename)

        # 修改文件名
        new_filename = filename.replace('《', '').replace('》', ' - ').replace(' (1)', '')

        # 构建新的文件路径
        new_file_path = os.path.join(directory, new_filename)

        # 重命名文件
        os.rename(file_path, new_file_path)