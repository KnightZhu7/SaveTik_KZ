from DrissionPage import ChromiumPage, ChromiumOptions, Chromium
from utils.link_parser import extract_douyin_url
import datetime as dt
import gc
import json
import time
from urllib.parse import urlparse

def parse_video_data(input_text):
    """
    输入抖音链接或包含链接的文本，解析视频数据，提取指定字段并识别编码格式。
    
    :param input_text: 包含抖音链接的字符串
    :return: (解析后的视频信息列表, 视频元数据字典)
    """
    # 1. 提取有效链接
    video_link = extract_douyin_url(input_text)
    if not video_link:
        raise Exception("未检测到有效的抖音链接，请检查输入内容")

    # 2. 使用 DrissionPage 获取数据
    co = ChromiumOptions()
    
    # 基础无头模式
    co.headless(True) 
    
    # 【核心修改】添加新版无头参数，解决 Mac Dock 栏图标跳动问题
    # Debug 时需要把下面这行注释掉，否则它会覆盖 headless(False) 强制开启无头模式！
    co.set_argument('--headless=new') 
    
    # 【核心修改】禁用首次运行欢迎页和默认浏览器检查
    # 解决在他人电脑（新环境）上运行时弹出“欢迎使用Chrome”窗口导致脚本失效的问题
    co.set_argument('--no-first-run')
    co.set_argument('--no-default-browser-check')
    
    # 可选：防止在某些 Mac 系统上创建初始窗口
    # co.set_argument('--no-startup-window')
    
    dp = ChromiumPage(addr_or_opts=co)
    # ==================== 修改结束 ====================
    try:
        # 同时监听视频详情和图文/Live图详情的接口
        dp.listen.start(['web/aweme/detail/', 'web/aweme/post/'])
        dp.get(video_link)
        res = dp.listen.wait(timeout=15)
        ua = dp.user_agent  # 自动获取浏览器当前使用的真实 User-Agent
        if not res:
            raise Exception("该链接不是有效的抖音内容链接，请检查后重试")
        
        # 容错与 Debug：如果返回的是字符串，尝试手动转为 JSON 字典
        body_data = res.response.body
        if isinstance(body_data, str):
            try:
                body_data = json.loads(body_data)
                # 再次检查是否为空或异常，某些情况下 DrissionPage 可能返回空 JSON 字符串
                if not body_data:
                     raise ValueError("解析为空 JSON 数据")
            except json.JSONDecodeError:
                # 如果无法解析为 JSON，说明多半是被风控拦截或抓错了包，打印前 200 个字符进行 Debug
                print("[!] Debug: 拦截到异常！浏览器将暂停 20 秒，请立刻查看弹出的 Chrome 窗口是否遇到验证码或报错！")
                time.sleep(3600)  # 给足时间让你肉眼排查浏览器到底卡在哪了
                error_snippet = body_data[:200].replace('\n', ' ')
                print(f"[!] Debug: 获取到的 body 内容 -> {error_snippet}")
                raise Exception("解析失败：返回的不是有效的 JSON 数据，可能遭遇了反爬验证")
                
        # 根据请求 URL 区分是视频详情还是图文/Live图详情
        url_path = res.request.url
        aweme_data = None
        
        if 'web/aweme/detail/' in url_path:
            aweme_data = body_data.get('aweme_detail')
        elif 'web/aweme/post/' in url_path:
            aweme_list = body_data.get('aweme_list', [])
            aweme_data = aweme_list[0] if aweme_list else None # 通常目标内容在第一个
            
    finally:
        dp.quit()

    if not aweme_data:
        raise Exception("解析失败：未能获取到有效内容数据")

    # 提取元数据用于命名
    nickname = aweme_data.get('author', {}).get('nickname', 'unknown')
    create_time_ts = aweme_data.get('create_time', 0)
    create_time = dt.datetime.fromtimestamp(create_time_ts).strftime('%Y-%m-%d_%H-%M-%S')
    
    metadata = {
        'nickname': nickname,
        'create_time': create_time,
        'user_agent': ua
    }
    
    # --- 新增：判断是图文/Live图还是视频 ---
    images = aweme_data.get('images')
    if images:
        parsed_media_list = []
        is_live_photo_content = False
        
        for img_item in images:
            live_photo_type = img_item.get('live_photo_type', 0)
            
            # 提取视频链接，辅助判断是否为 Live 图
            live_video_url_list = []
            video_data = img_item.get('video', {})
            if video_data:
                # 优先尝试从 play_addr 提取
                live_video_url_list = video_data.get('play_addr', {}).get('url_list', [])
                # 辅助判断：如果没有，则尝试从 bit_rate 结构中提取
                if not live_video_url_list:
                    bit_rate_list = video_data.get('bit_rate', [])
                    if bit_rate_list and isinstance(bit_rate_list, list):
                        live_video_url_list = bit_rate_list[0].get('play_addr', {}).get('url_list', [])

            # 如果拥有 live_photo_type 标识，或者确实包含了视频链接，就认定为 Live 图
            is_this_live_photo = (live_photo_type == 1) or bool(live_video_url_list)
            if is_this_live_photo:
                is_live_photo_content = True # 只要有一个是 Live 图，就标记整个内容为 Live 图
            
            url_list = img_item.get('url_list', [])
            target_jpeg_url = None
            
            # 优先从 url_list 倒序查找 .jpeg 结尾的链接
            for url in reversed(url_list):
                parsed_path = urlparse(url).path
                if parsed_path.lower().endswith('.jpeg'):
                    target_jpeg_url = url
                    break
            
            # 如果没有找到 .jpeg，则使用 url_list 中的最后一个链接作为兜底 (通常是最高质量)
            if not target_jpeg_url and url_list:
                target_jpeg_url = url_list[-1]
            
            image_info = {
                'image_url': target_jpeg_url,
                'width': img_item.get('width', 0),
                'height': img_item.get('height', 0)
            }
            
            # 如果是 Live 图，提取对应的视频链接
            if is_this_live_photo and live_video_url_list:
                image_info['live_video_url'] = live_video_url_list[0]
            
            parsed_media_list.append(image_info)
            
        media_type = "live_photo" if is_live_photo_content else "image"
        return media_type, parsed_media_list, metadata

    # 如果不是图文/Live图，那就是视频
    video = aweme_data.get('video', {})
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
            
    return "video", list(results.values()), metadata

def force_release_mac_memory():
    """
    当 SwiftUI 前端点击“清除”时调用。
    由于你的 parse 逻辑已经包含了 dp.quit()，这里主要负责强制打破 Python 循环引用，
    将 Python 虚拟机占据的“高水位线”空闲内存强制还给 macOS 系统。
    """
    print("[*] 收到前端清除指令，正在执行深度垃圾回收...")
    
    # 强制执行第 2 代（最深层级）的垃圾回收
    # 这会扫描并清理所有 DrissionPage 遗留的隐性闭包、字典和列表碎片
    released_objects = gc.collect(2)
    
    print(f"[+] 内存已彻底归还 macOS！本次回收了 {released_objects} 个顽固对象。")