import os
import subprocess
import platform
import customtkinter
import shutil

def build():
    # 1. 获取 customtkinter 的安装路径（打包资源必需）
    ctk_path = os.path.dirname(customtkinter.__file__)
    
    # 2. 根据操作系统设置路径分隔符
    # Windows 使用 ;  macOS/Linux 使用 :
    sep = ';' if platform.system() == "Windows" else ':'
    app_name = 'SaveTik_KZ'
    is_mac = platform.system() == "Darwin"
    
    # 3. 构建 PyInstaller 命令
    cmd = [
        'pyinstaller',
        '--noconsole',          # 不显示命令行窗口
        f'--add-data={ctk_path}{sep}customtkinter', # 包含 customtkinter 资源
        '--paths=.',            # 显式指定搜索路径为当前目录
        '--collect-all=DrissionPage', # 完整收集 DrissionPage 依赖，防止运行时报错
        f'--name={app_name}',    # 生成的应用名称
        '--clean',              # 打包前清理临时文件
        'main.py'               # 入口文件
        # 如果有额外的资源文件，按如下格式添加：
        # f'--add-data=config.json{sep}.', 
        # f'--add-data=assets{sep}assets',
    ]

    # Windows 建议使用 --onefile 方便分发
    # macOS 建议使用默认的 --onedir 模式生成 .app，稳定性更高且符合系统规范
    if not is_mac:
        cmd.append('--onefile')
    
    # 如果你有图标文件，可以取消下面两行的注释并替换图标路径
    # icon_ext = '.ico' if platform.system() == "Windows" else '.icns'
    # if os.path.exists(f'icon{icon_ext}'):
    #     cmd.extend(['--icon', f'icon{icon_ext}'])

    print(f"[*] 正在开始打包流程 (系统: {platform.system()})...")
    try:
        subprocess.run(cmd, check=True)
        
        # 4. 打包成功后清理临时文件
        print("[*] 正在清理临时构建文件...")
        if os.path.exists('build'):
            shutil.rmtree('build')
        spec_file = f"{app_name}.spec"
        if os.path.exists(spec_file):
            os.remove(spec_file)

        # 5. macOS 特有修复：赋予包内二进制执行权限并移除隔离标识
        if platform.system() == "Darwin":
            app_path = os.path.join('dist', f'{app_name}.app')
            inner_binary = os.path.join(app_path, 'Contents', 'MacOS', app_name)
            if os.path.exists(inner_binary):
                subprocess.run(['chmod', '+x', inner_binary])
            # 移除 macOS 的隔离属性，解决“无法打开”或“已损坏”的问题
            subprocess.run(['xattr', '-cr', app_path])
            
        print("\n" + "="*30)
        print("[+] 打包成功！")
        print(f"[+] 可执行文件位于: {os.path.join(os.getcwd(), 'dist')}")
        print("="*30)
    except subprocess.CalledProcessError:
        print("\n[-] 打包失败，请检查控制台输出错误信息。")
    except Exception as e:
        print(f"\n[-] 发生未知错误: {e}")

if __name__ == "__main__":
    build()