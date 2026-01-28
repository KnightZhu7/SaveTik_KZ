import requests as req
import os

def download_video_stream(stream_info, metadata):
    """
    下载指定的视频流
    :param stream_info: video_parser 返回的单个视频流信息
    :param metadata: 包含 nickname 和 create_time 的字典
    """
    nickname = metadata.get('nickname', 'unknown')
    create_time = metadata.get('create_time', 'unknown')
    
    # 提取流信息
    height = stream_info.get('height', '0')
    width = stream_info.get('width', '0')
    encoding = stream_info.get('encoding', 'H264')
    bit_rate = stream_info.get('bit_rate', '0')
    url_list = stream_info.get('url_list', [])

    if not url_list:
        print("[-] 错误：该视频流没有可用的下载链接。")
        return

    # 准确对应 url_list[0]
    video_url = url_list[0]

    # 构造文件名: {nickname}_{create_time}_{分辨率}p_{编码格式}_{码率信息}.mp4
    filename = f"{nickname}_{create_time}_{height}*{width}p_{encoding}_{bit_rate}.mp4"
    
    headers = {
        'referer': 'https://www.douyin.com/', 
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36', 
    }

    save_dir = "VideoDownload"
    os.makedirs(save_dir, exist_ok=True)
    save_path = os.path.join(save_dir, filename)

    print(f"[+] 正在下载: {filename}")
    try:
        response = req.get(video_url, headers=headers, stream=True)
        response.raise_for_status()
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"[+] 下载成功！文件保存为: {save_path}")
    except Exception as e:
        print(f"[-] 下载失败: {e}")
