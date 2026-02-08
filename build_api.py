import os
import sys
import subprocess
import platform
import shutil

def build_api():
    # 1. 基础配置
    app_name = 'api_server' 
    is_mac = platform.system() == "Darwin"
    sep = ';' if platform.system() == "Windows" else ':'

    # 2. 构建 PyInstaller 命令
    cmd = [
        'pyinstaller',
        '--clean',           # 清理缓存
        '--noconsole',       # 不要黑窗口
        '--onedir',          # 🔥 关键修改：改成文件夹模式 (启动速度快 10 倍)
        f'--name={app_name}',
        
        # 依赖收集
        '--collect-all=DrissionPage',
        '--collect-all=uvicorn',
        '--collect-all=fastapi',
        
        # 路径搜索
        '--paths=.',
    ]

    # 3. 处理资源文件
    # 将 utils 文件夹放入打包后的根目录
    cmd.extend(['--add-data', f'utils{sep}utils'])

    # 入口文件
    cmd.append('api_server.py')

    print(f"[*] 正在开始打包 (系统: {platform.system()})...")
    print(f"[*] 模式: 文件夹模式 (--onedir)")
    
    try:
        # 执行打包
        subprocess.run(cmd, check=True)
        
        # 4. 清理临时文件 (build 文件夹和 spec 文件)
        print("[*] 正在清理临时文件...")
        if os.path.exists('build'):
            shutil.rmtree('build')
        if os.path.exists(f"{app_name}.spec"):
            os.remove(f"{app_name}.spec")

        # 5. macOS 特有处理
        if is_mac:
            # 注意：onedir 模式下，dist/api_server 是一个文件夹
            bundle_path = os.path.join('dist', app_name) 
            # 真正的可执行文件在文件夹里面，名字也叫 api_server
            executable_binary = os.path.join(bundle_path, app_name)
            
            print("[*] 执行 macOS 权限修复...")
            if os.path.exists(executable_binary):
                # 赋予二进制文件执行权限
                subprocess.run(['chmod', '+x', executable_binary], check=True)
                
                # 对整个文件夹移除隔离属性 (避免 macOS 弹窗报错)
                subprocess.run(['xattr', '-cr', bundle_path], check=True)
                
                # 对内部二进制文件签名 (防止 Killed: 9)
                subprocess.run(['codesign', '--force', '--deep', '--sign', '-', executable_binary], check=True)
            
        print("\n" + "="*40)
        print(f"[+] 打包成功！")
        print(f"[+] 产物类型: 文件夹 (Folder)")
        print(f"[+] 产物位置: dist/{app_name}")
        print(f"[+] 重要提示: 拖入 Xcode 时请选择 'Create folder references' (蓝色文件夹图标)！")
        print("="*40)

    except subprocess.CalledProcessError as e:
        print(f"\n[-] 打包过程中出错: {e}")
    except Exception as e:
        print(f"\n[-] 发生未知错误: {e}")

if __name__ == "__main__":
    build_api()