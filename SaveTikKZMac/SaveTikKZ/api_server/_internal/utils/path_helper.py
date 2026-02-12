import os
import sys

def get_resource_path(relative_path: str) -> str:
    """
    获取资源的绝对路径，兼容 PyInstaller 打包后的环境 (_MEIPASS)
    """
    try:
        # PyInstaller 打包后，资源会被解压到 sys._MEIPASS 目录下
        base_path = sys._MEIPASS
    except Exception:
        # 未打包的开发环境下，使用当前脚本所在的绝对路径
        base_path = os.path.abspath(".")

    return os.path.join(base_path, relative_path)