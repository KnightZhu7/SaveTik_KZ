from DrissionPage import ChromiumPage
import datetime as dt
import requests as req
headers = {
    'referer': 'https://www.douyin.com/', 
    'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36', 
}
video_link = 'https://v.douyin.com/whgf3ItLCDg/'
# video_link = 'https://www.douyin.com/video/7599212845393335717'
dp = ChromiumPage()
dp.listen.start('web/aweme/detail/')
dp.get(video_link)
r = dp.listen.wait()
json_data = r.response.body
aweme_detail = json_data['aweme_detail']
nickname = aweme_detail['author']['nickname']
dt_create_time = dt.datetime.fromtimestamp(aweme_detail['create_time'])
create_time = dt_create_time.strftime('%Y-%m-%d %H-%M-%S')
video_url = aweme_detail['video']['play_addr']['url_list'][0]
video = req.get(video_url, headers=headers).content
with open(f'{nickname}_{create_time}.mp4', 'wb') as f:
    f.write(video)