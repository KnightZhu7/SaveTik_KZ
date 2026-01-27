from DrissionPage import ChromiumPage, ChromiumOptions, Chromium
import datetime as dt
import requests as req
import os
from utils.link_parser import extract_douyin_url

def download_douyin_video(input_text: str):
    """
    封装后的抖音视频下载函数
    :param input_text: 包含抖音链接的原始文本或直接链接
    """
    # 1. 提取有效链接
    video_link = extract_douyin_url(input_text)
    if not video_link:
        print("[-] 错误：未在输入内容中找到有效的抖音链接！")
        return

    print(f"[+] 识别到有效链接: {video_link}")
    
    headers = {
        'referer': 'https://www.douyin.com/', 
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36', 
    }

    # 2. 使用 DrissionPage 获取视频详情
    browser = Chromium()
    tab = browser.latest_tab
    co = ChromiumOptions()
    co.headless(True)
    dp = ChromiumPage()
    try:
        dp.listen.start('web/aweme/detail/')
        dp.get(video_link)
        res = dp.listen.wait()
        json_data = res.response.body
        
        if not json_data or 'aweme_detail' not in json_data:
            print("[-] 错误：未能获取到视频详情，请检查链接是否有效。")
            return

        aweme_detail = json_data['aweme_detail']
        nickname = aweme_detail['author']['nickname']
        dt_create_time = dt.datetime.fromtimestamp(aweme_detail['create_time'])
        create_time = dt_create_time.strftime('%Y-%m-%d %H-%M-%S')
        video_url = aweme_detail['video']['bit_rate'][3]['play_addr']['url_list'][0]

        # 3. 下载并保存视频
        print(f"[+] 正在下载来自 {nickname} 的视频...")
        video_content = req.get(video_url, headers=headers).content
        
        # 设置保存路径为 VideoDownload 文件夹
        save_dir = "VideoDownload"
        os.makedirs(save_dir, exist_ok=True)
            
        filename = f"{nickname}_{create_time}.mp4"
        save_path = os.path.join(save_dir, filename)
        with open(save_path, 'wb') as f:
            f.write(video_content)
        print(f"[+] 下载成功！文件保存为: {save_path}")
    finally:
        tab.close()
        # pass
