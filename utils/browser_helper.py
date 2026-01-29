import platform
import os
import shutil
from DrissionPage import ChromiumOptions

def init_browser_config():
    """
    自动初始化并保存 Chrome 浏览器路径。
    仅在未设置或路径失效时执行，确保跨平台兼容性。
    """
    co = ChromiumOptions()
    current_path = co.browser_path
    
    # 如果当前路径已设置且有效，则跳过
    if current_path and os.path.isabs(current_path) and os.path.exists(current_path):
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
    else:
        print("[-] 环境检查：未能自动找到 Chrome，请确保已安装浏览器。")