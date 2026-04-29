import re

def extract_douyin_url(text: str) -> str:
    """
    从输入的文本中提取抖音有效链接。
    支持短链接 (v.douyin.com) 和 视频详情页链接 (www.douyin.com/video/)。
    
    Args:
        text (str): 包含抖音链接的原始文本
        
    Returns:
        str: 提取出的有效 URL，如果未找到则返回空字符串
    """
    # 正则表达式说明：
    # https?:// : 匹配 http 或 https
    # (?:v\.douyin\.com|www\.douyin\.com/video) : 非捕获分组，匹配短链域名或视频详情页路径
    # /\S+ : 匹配斜杠后跟随的非空白字符，直到遇到空格或字符串末尾
    pattern = r'(https?://(?:v\.douyin\.com|www\.douyin\.com/(?:video|note))/\S+)'
    
    match = re.search(pattern, text)
    if match:
        return match.group(1).strip()
    return ""

# if __name__ == "__main__":
#     # 测试用例
#     share_text = "2.56 复制打开抖音，看看【新孖孖的作品】唉 你抛弃我的时候 会不会想起刚开始你夸我好可爱 ... https://v.douyin.com/whgf3ItLCDg/ 08/09 p@d.NW zGi:/"
#     video_link = "https://www.douyin.com/video/7599212845393335717"
    
#     print(f"提取短链接结果: {extract_douyin_url(share_text)}")
#     print(f"提取视频链接结果: {extract_douyin_url(video_link)}")