import os
import shutil

def move_txt_files(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.txt'):
                file_path = os.path.join(root, file)
                folder_path = os.path.join(root, os.path.splitext(file)[0])  # 获取文件名（不包含扩展名）作为文件夹名
                os.makedirs(folder_path, exist_ok=True)  # 创建目标文件夹（如果不存在）
                shutil.move(file_path, folder_path)  # 移动文件到目标文件夹

# 指定要移动文件的目录
directory = r'C:\Users\lunto\Desktop\New'  # 替换为实际的目录路径

# 移动txt文件到与其名称相同的文件夹中
move_txt_files(directory)