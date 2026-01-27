from DrissionPage import ChromiumPage, ChromiumOptions, Chromium
from utils.link_parser import extract_douyin_url

def parse_video_data(input_text):
    """
    输入抖音链接或包含链接的文本，解析视频数据，提取指定字段并识别编码格式。
    
    :param input_text: 包含抖音链接的字符串
    :return: 解析后的视频信息列表
    """
    # 1. 提取有效链接
    video_link = extract_douyin_url(input_text)
    if not video_link:
        return []

    # 2. 使用 DrissionPage 获取数据
    browser = Chromium()
    tab = browser.latest_tab
    co = ChromiumOptions()
    co.headless(True)
    dp = ChromiumPage()
    try:
        dp.listen.start('web/aweme/detail/')
        dp.get(video_link)
        res = dp.listen.wait()
        if not res:
            return []
        aweme_detail = res.response.body.get('aweme_detail', {})
    finally:
        tab.close()

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
                'FPS': item.get('FPS', ''),
                'bit_rate': item.get('bit_rate', ''),
                'data_size': play_addr.get('data_size', ''),
                'file_hash': file_hash,
                'height': play_addr.get('height', ''),
                'width': play_addr.get('width', ''),
                'url_list': play_addr.get('url_list', []),
                'encoding': encoding
            }
            
    return list(results.values())