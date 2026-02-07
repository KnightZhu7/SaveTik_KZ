from DrissionPage import ChromiumPage, ChromiumOptions, Chromium
from utils.link_parser import extract_douyin_url
import datetime as dt

def parse_video_data(input_text):
    """
    输入抖音链接或包含链接的文本，解析视频数据，提取指定字段并识别编码格式。
    
    :param input_text: 包含抖音链接的字符串
    :return: (解析后的视频信息列表, 视频元数据字典)
    """
    # 1. 提取有效链接
    video_link = extract_douyin_url(input_text)
    if not video_link:
        return [], {}

    # 2. 使用 DrissionPage 获取数据
    co = ChromiumOptions().headless(True)
    dp = ChromiumPage(addr_or_opts=co)
    try:
        dp.listen.start('web/aweme/detail/')
        dp.get(video_link)
        res = dp.listen.wait()
        ua = dp.user_agent  # 自动获取浏览器当前使用的真实 User-Agent
        if not res:
            return [], {}
        aweme_detail = res.response.body.get('aweme_detail', {})
    finally:
        dp.quit()

    if not aweme_detail:
        return [], {}

    # 提取元数据用于命名
    nickname = aweme_detail.get('author', {}).get('nickname', 'unknown')
    create_time_ts = aweme_detail.get('create_time', 0)
    create_time = dt.datetime.fromtimestamp(create_time_ts).strftime('%Y-%m-%d_%H-%M-%S')
    
    metadata = {
        'nickname': nickname,
        'create_time': create_time,
        'user_agent': ua
    }

    video = aweme_detail.get('video', {})
    bit_rate_list = video.get('bit_rate', [])
    
    # 预先获取 H265 对应的 hash，用于辅助判断编码格式
    h265_hash = video.get('play_addr_265', {}).get('file_hash')
    
    results = {}
    
    for item in bit_rate_list:
        play_addr = item.get('play_addr', {})
        file_hash = play_addr.get('file_hash')
        
        if not file_hash:
            continue
            
        # 编码形式判断逻辑：优先根据 url_key 判断，其次根据 gear_name 或 hash 兜底
        url_key = play_addr.get('url_key', '')
        if '_bytevc1_' in url_key:
            encoding = 'H265'
        elif '_h264_' in url_key:
            encoding = 'H264'
        else:
            encoding = 'H264'
            
        if file_hash in results:
            # 如果 hash 一样，合并 url_list
            existing_urls = results[file_hash]['url_list']
            for url in play_addr.get('url_list', []):
                if url not in existing_urls:
                    existing_urls.append(url)
        else:
            # 提取所需字段，没有的信息默认为空字符串或空列表
            results[file_hash] = {
                'fps': item.get('FPS', ''),
                'bit_rate': item.get('bit_rate', ''),
                'HDR_bit': item.get('HDR_bit', ''),
                'HDR_type': item.get('HDR_type', ''),
                'data_size': play_addr.get('data_size', ''),
                'file_hash': file_hash,
                'height': play_addr.get('height', ''),
                'width': play_addr.get('width', ''),
                'url_list': play_addr.get('url_list', []),
                'encoding': encoding,
                'nickname': nickname,
                'create_time': create_time
            }
            
    return list(results.values()), metadata