from DrissionPage import ChromiumOptions

path = r'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'  # 请改为你电脑内Chrome可执行文件路径
ChromiumOptions().set_browser_path(path).save()

