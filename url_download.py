from utils.url_downloader import download_file
def run():
    user_input_url = input("输入URL: \n> ")
    user_input_filename = input("输入文件名(包括后缀：视频.mp4，图片.jpeg): \n> ")
    if user_input_url.strip() and user_input_filename.strip():
        download_file(user_input_url, user_input_filename)

if __name__ == "__main__":
    run()