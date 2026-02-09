import platform
import os
import shutil
import sys
from DrissionPage import ChromiumOptions

def init_browser_config():
    """
    自动初始化并保存 Chrome 浏览器路径。
    仅在未设置或路径失效时执行，确保跨平台兼容性。
    """
    co = ChromiumOptions()
    current_path = co.browser_path
    
    # 如果当前路径已设置且有效，或者处于打包运行状态（frozen），则跳过保存逻辑
    # 打包状态下每次启动动态查找路径，避免因权限问题导致 save() 崩溃
    if (current_path and os.path.isabs(current_path) and os.path.exists(current_path)) or getattr(sys, 'frozen', False):
        # 如果是打包环境，虽然不 save，但仍需确保本次运行能找到浏览器
        if not (current_path and os.path.exists(current_path)):
            find_and_set_runtime_path(co)
        return

    system = platform.system()
    path = None
    
    if system == "Windows":
        paths = [
            os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "Google\\Chrome\\Application\\chrome.exe"),
            os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "Google\\Chrome\\Application\\chrome.exe"),
            os.path.join(os.environ.get("LocalAppData", ""), "Google\\Chrome\\Application\\chrome.exe")
        ]
        for p in paths:
            if os.path.exists(p):
                path = p
                break
    elif system == "Darwin":  # macOS
        p = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        if os.path.exists(p):
            path = p
    
    if not path:
        path = shutil.which("google-chrome") or shutil.which("chrome")
    
    if path:
        co.set_browser_path(path).save()
        print(f"[+] 环境检查：已自动识别并保存 Chrome 路径: {path}")

def find_and_set_runtime_path(co):
    """运行时动态查找并设置浏览器路径（不保存到磁盘）"""
    system = platform.system()
    path = None
    if system == "Windows":
        paths = [
            os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "Google\\Chrome\\Application\\chrome.exe"),
            os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "Google\\Chrome\\Application\\chrome.exe")
        ]
        for p in paths:
            if os.path.exists(p):
                path = p
                break
    elif system == "Darwin":
        p = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        if os.path.exists(p):
            path = p
    
    if path:
        co.set_browser_path(path)
    else:
        print("[-] 环境检查：未能自动找到 Chrome，请确保已安装浏览器。")