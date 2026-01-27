from utils.video_downloader import download_douyin_video

def run():
    user_input = input("请输入抖音分享视频链接: \n> ")
    if user_input.strip():
        download_douyin_video(user_input)

if __name__ == "__main__":
    run()