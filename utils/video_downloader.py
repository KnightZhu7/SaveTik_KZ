import requests as req
import re
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
    height = stream_info.get('height', 0)
    width = stream_info.get('width', 0)
    try:
        # 取长宽中较短的一边作为分辨率标识 (如 1080p)
        res_p = min(int(height), int(width))
    except (ValueError, TypeError):
        res_p = height

    fps = stream_info.get('fps', '0')
    encoding = stream_info.get('encoding', 'H264')
    bit_rate = stream_info.get('bit_rate', '0')
    url_list = stream_info.get('url_list', [])

    if not url_list:
        print("[-] 错误：该视频流没有可用的下载链接。")
        return

    # 准确对应 url_list[0]
    video_url = url_list[0]

    # HDR 标识判断
    is_hdr = stream_info.get('HDR_bit') == "10" and stream_info.get('HDR_type') == "1"
    hdr_tag = "_HDR" if is_hdr else ""

    # 构造文件名: {nickname}_{create_time}_{短边}p_{fps}fps_{encoding}_{bit_rate}{hdr_tag}.mp4
    raw_filename = f"{nickname}_{create_time}_{res_p}p_{fps}fps_{encoding}_{bit_rate}{hdr_tag}.mp4"

    safe_filename = re.sub(r'[<>:"/\\|?*]', '_', raw_filename)
    filename = safe_filename.strip()
    
    headers = {
        'referer': 'https://www.douyin.com/', 
        'user-agent': metadata.get('user_agent'), 
    }

    # 改进：使用用户主目录下的 Downloads 文件夹，确保在打包后仍有写入权限且路径明确
    home_dir = os.path.expanduser("~")
    save_dir = os.path.join(home_dir, "Downloads", "SaveTik_KZ")
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
        return True
    except Exception as e:
        print(f"[-] 下载失败: {e}")
        return False
