from DrissionPage import ChromiumPage, ChromiumOptions, Chromium
from utils.link_parser import extract_douyin_url
import datetime as dt
import gc
import json
import time

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
    # co = ChromiumOptions().headless(True)
    # dp = ChromiumPage(addr_or_opts=co)
    # ==================== 修改开始 ====================
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
        dp.listen.start('web/aweme/detail/')
        dp.get(video_link)
        res = dp.listen.wait(timeout=15)
        ua = dp.user_agent  # 自动获取浏览器当前使用的真实 User-Agent
        if not res:
            raise Exception("该链接不是有效的视频链接，请检查后重试")
        
        # 容错与 Debug：如果返回的是字符串，尝试手动转为 JSON 字典
        body_data = res.response.body
        if isinstance(body_data, str):
            try:
                body_data = json.loads(body_data)
            except json.JSONDecodeError:
                # 如果无法解析为 JSON，说明多半是被风控拦截或抓错了包，打印前 200 个字符进行 Debug
                print("[!] Debug: 拦截到异常！浏览器将暂停 20 秒，请立刻查看弹出的 Chrome 窗口是否遇到验证码或报错！")
                time.sleep(20)  # 给足时间让你肉眼排查浏览器到底卡在哪了
                error_snippet = body_data[:200].replace('\n', ' ')
                print(f"[!] Debug: 获取到的 body 内容 -> {error_snippet}")
                raise Exception("解析失败：返回的不是有效的 JSON 数据，可能遭遇了反爬验证")
                
        aweme_detail = body_data.get('aweme_detail')
    finally:
        dp.quit()

    if not aweme_detail:
        raise Exception("解析失败：未能获取到视频详情数据")

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