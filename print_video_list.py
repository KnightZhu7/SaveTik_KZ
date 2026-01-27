from utils.video_parser import parse_video_data
import json

def main():
    user_input = input("请输入抖音分享视频链接: \n> ")
    if not user_input.strip():
        return

    print("[+] 正在解析视频数据，请稍候...")
    video_info_list = parse_video_data(user_input)

    if not video_info_list:
        print("[-] 未能解析到视频信息，请检查链接是否有效。")
        return

    print(f"\n[+] 共找到 {len(video_info_list)} 个视频流信息：")
    print("-" * 50)

    for i, info in enumerate(video_info_list, 1):
        print(f"序号: {i}")
        print(f"编码格式: {info['encoding']}")
        print(f"分辨率: {info['width']}x{info['height']}")
        print(f"FPS: {info['FPS']}")
        print(f"比特率: {info['bit_rate']}")
        print(f"文件大小: {info['data_size']} bytes")
        print(f"文件哈希: {info['file_hash']}")
        print(f"URL 数量: {len(info['url_list'])}")
        print(f"首选链接: {info['url_list'][0] if info['url_list'] else '无'}")
        print("-" * 50)

if __name__ == "__main__":
    main()