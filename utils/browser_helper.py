import platform
import os
import shutil
import sys
from DrissionPage import ChromiumOptions

def _find_chrome_path():
    """统一查找 Chrome 路径的逻辑，增加注册表支持"""
    system = platform.system()

    if system == "Windows":
        # 1. 优先尝试从注册表查找 (最准确，支持自定义安装路径)
        try:
            import winreg
            # 检查 HKLM 和 HKCU 下的 App Paths
            for root in [winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER]:
                try:
                    with winreg.OpenKey(root, r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe") as key:
                        p, _ = winreg.QueryValueEx(key, "")
                        if p and os.path.exists(p):
                            return p
                except OSError:
                    continue
        except (ImportError, AttributeError):
            pass

        # 2. 尝试常见安装路径 (作为备份)
        paths = [
            os.path.join(os.environ.get("ProgramFiles", "C:\\Program Files"), "Google\\Chrome\\Application\\chrome.exe"),
            os.path.join(os.environ.get("ProgramFiles(x86)", "C:\\Program Files (x86)"), "Google\\Chrome\\Application\\chrome.exe"),
            os.path.join(os.environ.get("LocalAppData", ""), "Google\\Chrome\\Application\\chrome.exe")
        ]
        for p in paths:
            if os.path.exists(p):
                return p
    elif system == "Darwin":  # macOS
        p = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
        if os.path.exists(p):
            return p

    # 3. 最后尝试从环境变量 PATH 中查找 (支持已加入 PATH 的便携版)
    return shutil.which("google-chrome") or shutil.which("chrome")

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

    path = _find_chrome_path()
    if path:
        co.set_browser_path(path).save()
        print(f"[+] 环境检查：已自动识别并保存 Chrome 路径: {path}")

def find_and_set_runtime_path(co):
    """运行时动态查找并设置浏览器路径（不保存到磁盘）"""
    path = _find_chrome_path()
    if path:
        co.set_browser_path(path)
    else:
        print("[-] 环境检查：未能自动找到 Chrome，请确保已安装浏览器。")