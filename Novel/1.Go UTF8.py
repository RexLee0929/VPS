import os
import chardet
import codecs

def traverse_directory(directory):
    total_files = 0
    successful_files = 0
    failed_files = 0
    skipped_files = 0
    failed_file_list = []
    
    for root, dirs, files in os.walk(directory):
        for file_name in files:
            if file_name.endswith('.txt'):
                file_path = os.path.join(root, file_name)
                total_files += 1
                
                with open(file_path, 'rb') as file:
                    result = chardet.detect(file.read())

                src_encoding = result['encoding']
                
                try:
                    # 读取文件内容
                    with codecs.open(file_path, 'r', encoding=src_encoding) as file:
                        content = file.read()

                    # 将文件内容以UTF-8编码写回文件
                    with codecs.open(file_path, 'w', encoding='utf-8') as file:
                        file.write(content)
                        
                    if src_encoding == 'utf-8':
                        print(f"文件{file_name}编码为UTF-8，无需转换编码")
                        skipped_files += 1
                    else:
                        print(f"文件{file_name}由编码{src_encoding}，转换至UTF-8编码成功")
                        successful_files += 1
                        
                except UnicodeDecodeError as e:
                    print(f"文件{file_name}编码为{src_encoding}，转换至UTF-8编码失败")
                    failed_files += 1
                    failed_file_list.append((file_name, str(e)))
    
    print(f"本次运行共{total_files}个文件进行转换，转换成功{successful_files}个文件，转换失败{failed_files}个文件，跳过转换{skipped_files}个文件")
    
    if failed_files > 0:
        print("\n本次转换失败的文件为：")
        for file_name, error in failed_file_list:
            print(f"{file_name}\n{file_name}转换失败的原因是：{error}\n")

# 指定要处理的目录
directory = r'C:\Users\lunto\Desktop\New'  # 替换为实际的目录路径

# 执行递归遍历并转换编码
traverse_directory(directory)
