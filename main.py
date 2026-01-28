from utils.video_parser import parse_video_data
from utils.video_downloader import download_video_stream

def run():
    user_input = input("请输入抖音分享视频链接: \n> ")
    if not user_input.strip():
        return

    print("[+] 正在解析视频数据...")
    video_info_list, metadata = parse_video_data(user_input)

    if not video_info_list:
        print("[-] 解析失败，请检查链接。")
        return

    print(f"\n[+] 视频作者: {metadata['nickname']}")
    print(f"[+] 发布时间: {metadata['create_time']}")
    print("-" * 30)
    for i, info in enumerate(video_info_list, 1):
        print(f"{i}. 分辨率: {info['width']}x{info['height']} | 编码: {info['encoding']} | 码率: {info['bit_rate']}")
    print("-" * 30)

    choice = input("请输入要下载的序号 (多个用逗号隔开，输入 'all' 下载全部): \n> ").strip().lower()

    selected_indices = []
    if choice == 'all':
        selected_indices = list(range(len(video_info_list)))
    else:
        try:
            # 处理逗号分隔的输入
            selected_indices = [int(x.strip()) - 1 for x in choice.split(',') if x.strip()]
        except ValueError:
            print("[-] 输入无效。")
            return

    for idx in selected_indices:
        if 0 <= idx < len(video_info_list):
            download_video_stream(video_info_list[idx], metadata)
        else:
            print(f"[-] 序号 {idx+1} 不存在，跳过。")

if __name__ == "__main__":
    run()