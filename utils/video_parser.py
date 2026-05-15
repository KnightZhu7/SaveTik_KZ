from DrissionPage import ChromiumPage, ChromiumOptions, Chromium
from utils.link_parser import extract_douyin_url
import datetime as dt
import gc
import json
import time
from urllib.parse import urlparse
import re

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
    # co.headless(False) 
    
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
    
    try:
        ua = None
        aweme_data = None
        
        # 引入重试机制
        for attempt in range(2):
            if attempt > 0:
                print(f"[*] 首次未获取到有效数据，保留页面并执行 dp.refresh() 进行第 {attempt} 次重试...")
                time.sleep(1) # 刷新前稍微缓冲一下
            
            # 每次尝试前重新启动监听
            dp.listen.start(['web/aweme/detail/', 'web/aweme/post/'])
            dp.set.load_mode('none')
            
            if attempt == 0:
                dp.get(video_link)
            else:
                dp.refresh()
            
            res = dp.listen.wait(timeout=5)
            
            if not res:
                print("[Python 解析流] ➡️ 5秒未截获，触发强制 stop_loading() 释放数据包...")
                dp.stop_loading()
                
                res = dp.listen.wait(timeout=15)
            else:
                dp.stop_loading()
                
            dp.set.load_mode('normal')
            ua = dp.user_agent  # 自动获取浏览器当前使用的真实 User-Agent
            
            if not res:
                if attempt == 0:
                    continue  # 第一次如果完全没截获到请求，直接进入刷新重试循环
                else:
                    raise Exception("解析失败：可能遭遇了反爬验证，请稍后重试")
            
            # 容错与 Debug：如果返回的是字符串，尝试手动转为 JSON 字典
            body_data = res.response.body
            if isinstance(body_data, str):
                try:
                    body_data = json.loads(body_data)
                    # 再次检查是否为空或异常
                    if not body_data:
                         if attempt == 0:
                             continue # JSON 为空，走刷新重试流程
                         else:
                             raise ValueError("解析为空 JSON 数据")
                except json.JSONDecodeError:
                    # 【修复点】：第一次如果遇到非 JSON 格式（比如错抓了 HTML 页面），不报错，直接去重试
                    if attempt == 0:
                        print("[*] 解析 JSON 失败（可能抓到了非预期数据包），准备刷新页面重试...")
                        continue 
                    else:
                        print("[!] Debug: 重试后依然拦截到异常！浏览器将暂停，请立刻查看弹出的 Chrome 窗口是否遇到验证码或报错！")
                        raise Exception("解析失败：可能遭遇了反爬验证，请稍后重试")
                
            current_url = dp.url
            id_match = re.search(r'/(?:video|note)/(\d+)', current_url)
            target_aweme_id = id_match.group(1) if id_match else None
            
            url_path = res.request.url
            aweme_data = None
            
            if 'web/aweme/detail/' in url_path:
                aweme_data = body_data.get('aweme_detail')
            elif 'web/aweme/post/' in url_path:
                aweme_list = body_data.get('aweme_list', [])
                if aweme_list:
                    first_item = aweme_list[0]
                    # 不遍历，只校验第一个作品。如果目标 ID 存在且对不上，直接让 aweme_data 保持为 None
                    if not target_aweme_id or str(first_item.get('aweme_id')) == target_aweme_id:
                        aweme_data = first_item

            # 3. 终极兜底方案：抛弃遍历，一步到位直接正则匹配含有目标 ID 的 __pace_f.push 块
            if not aweme_data and target_aweme_id:
                print(f"[!] 接口数据未能匹配目标 ID ({target_aweme_id})，正直接匹配 doc 源码...")
                html_content = dp.html
                
                pattern = r'self\.__pace_f\.push\(\[\s*\d+,\s*"((?:[^"\\]|\\.)*?\\"(?:awemeId|aweme_id)\\":\\"' + target_aweme_id + r'\\"(?:[^"\\]|\\.)*?)"'
                match = re.search(pattern, html_content)
                
                if match:
                    try:
                        raw_str = '"' + match.group(1) + '"'
                        decoded_str = json.loads(raw_str)
                        
                        json_start = re.search(r'([\[\{])', decoded_str)
                        if json_start:
                            clean_json_str = decoded_str[json_start.start():]
                            parsed_obj = json.loads(clean_json_str)
                            
                            if isinstance(parsed_obj, list):
                                for item in parsed_obj:
                                    if isinstance(item, dict) and str(item.get('awemeId') or item.get('aweme_id', '')) == target_aweme_id:
                                        aweme_data = item.get('aweme', {}).get('detail', item)
                                        break
                            elif isinstance(parsed_obj, dict):
                                if str(parsed_obj.get('awemeId') or parsed_obj.get('aweme_id', '')) == target_aweme_id:
                                    aweme_data = parsed_obj.get('aweme', {}).get('detail', parsed_obj)
                                    
                        if aweme_data:
                            print(f"[+] 成功通过直接匹配 doc 源码获取到作品 ({target_aweme_id}) 数据！")
                    except Exception as e:
                        pass
            
            # --- 核心判断：是否成功获取到了数据 ---
            if aweme_data:
                # 如果拿到数据了，直接打断循环，往下走，不再重试
                break
            
    finally:
        # pass
        dp.quit()

    if not aweme_data:
        raise Exception("解析失败：经过刷新重试后仍未能获取到有效内容数据")
    
    # 1. 提取元数据用于命名
    author_info = aweme_data.get('author') or aweme_data.get('authorInfo', {})
    nickname = author_info.get('nickname', 'unknown')
    
    create_time_ts = aweme_data.get('create_time') or aweme_data.get('createTime', 0)
    create_time = dt.datetime.fromtimestamp(create_time_ts).strftime('%Y-%m-%d_%H-%M-%S')
    
    metadata = {
        'nickname': nickname,
        'create_time': create_time,
        'user_agent': ua
    }
    
    # 2. 判断是图文/Live图还是视频
    images = aweme_data.get('images')
    if images:
        parsed_media_list = []
        is_live_photo_content = False
        
        for img_item in images:
            # 兼容 live_photo_type 和 livePhotoType
            live_photo_type = img_item.get('live_photo_type') or img_item.get('livePhotoType', 0)
            
            # 提取可能存在的 Live 视频链接
            live_video_url_list = []
            video_data = img_item.get('video', {})
            if video_data:
                # 兼容 play_addr 和 playAddr
                play_addr = video_data.get('play_addr') or video_data.get('playAddr')
                
                # 格式 1: 接口格式 {'url_list': ['http...']}
                if isinstance(play_addr, dict):
                    live_video_url_list = play_addr.get('url_list') or play_addr.get('urlList', [])
                # 格式 2: 源码格式 [{'src': 'http...'}]
                elif isinstance(play_addr, list) and len(play_addr) > 0:
                    live_video_url_list = [item.get('src') for item in play_addr if isinstance(item, dict) and item.get('src')]
                
                # 辅助判断：如果上面没取到，尝试从 bit_rate / bitRateList 中提取
                if not live_video_url_list:
                    bit_rate_list = video_data.get('bit_rate') or video_data.get('bitRateList', [])
                    if bit_rate_list and isinstance(bit_rate_list, list):
                        first_bit = bit_rate_list[0]
                        pa = first_bit.get('play_addr') or first_bit.get('playAddr')
                        if isinstance(pa, dict):
                            live_video_url_list = pa.get('url_list') or pa.get('urlList', [])
                        elif isinstance(pa, list):
                            live_video_url_list = [item.get('src') for item in pa if isinstance(item, dict) and item.get('src')]

            # 认定 Live 图的条件
            is_this_live_photo = (live_photo_type == 1) or bool(live_video_url_list)
            if is_this_live_photo:
                is_live_photo_content = True
            
            # 兼容 url_list 和 urlList
            url_list = img_item.get('url_list') or img_item.get('urlList', [])
            target_jpeg_url = None
            
            # 优先从列表倒序查找 .jpeg 结尾的链接
            for url in reversed(url_list):
                parsed_path = urlparse(url).path
                if parsed_path.lower().endswith('.jpeg'):
                    target_jpeg_url = url
                    break
            
            # 兜底：如果没找到 .jpeg，默认使用最后一个链接
            if not target_jpeg_url and url_list:
                target_jpeg_url = url_list[-1]
            
            image_info = {
                'image_url': target_jpeg_url,
                'width': img_item.get('width', 0),
                'height': img_item.get('height', 0)
            }
            
            if is_this_live_photo and live_video_url_list:
                image_info['live_video_url'] = live_video_url_list[0]
            
            parsed_media_list.append(image_info)
            
        media_type = "live_photo" if is_live_photo_content else "image"
        return media_type, parsed_media_list, metadata

    # 3. 如果不是图文/Live图，那就是视频
    video = aweme_data.get('video', {})
    bit_rate_list = video.get('bit_rate') or video.get('bitRateList', [])
    
    results = {}
    for item in bit_rate_list:
        play_addr = item.get('play_addr') or item.get('playAddr', {})
        
        # 兼容源码 playAddr 是列表的情况
        if isinstance(play_addr, list):
            urls = [u.get('src') for u in play_addr if isinstance(u, dict) and u.get('src')]
            file_hash = item.get('playAddrFileHash', f"hash_{len(results)}") # doc格式可能没有hash，生成一个临时的
            data_size = item.get('playAddrSize', '')
            width = item.get('width', '')
            height = item.get('height', '')
        else:
            urls = play_addr.get('url_list') or play_addr.get('urlList', [])
            file_hash = play_addr.get('file_hash') or item.get('playAddrFileHash')
            data_size = play_addr.get('data_size') or item.get('playAddrSize', '')
            width = play_addr.get('width') or item.get('width', '')
            height = play_addr.get('height') or item.get('height', '')
            
        if not file_hash and not urls:
            continue
            
        # 编码判定
        url_key = play_addr.get('url_key', '') if isinstance(play_addr, dict) else ''
        if '_bytevc1_' in url_key:
            encoding = 'H265'
        elif '_h264_' in url_key:
            encoding = 'H264'
        else:
            encoding = 'H264'
            
        if file_hash in results:
            existing_urls = results[file_hash]['url_list']
            for url in urls:
                if url not in existing_urls:
                    existing_urls.append(url)
        else:
            results[file_hash] = {
                'fps': item.get('FPS', '') or item.get('fps', ''),
                'bit_rate': item.get('bit_rate', '') or item.get('bitRate', ''),
                'HDR_bit': item.get('HDR_bit', '') or item.get('HDRBit', ''),
                'HDR_type': item.get('HDR_type', '') or item.get('HDRType', ''),
                'data_size': data_size,
                'file_hash': file_hash,
                'height': height,
                'width': width,
                'url_list': urls,
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