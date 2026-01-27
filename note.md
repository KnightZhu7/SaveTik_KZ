# SaveTik流程

---
## 0.环境准备
**安装Chrome浏览器**

**Python**
* `pip install requests` 和 `pip install DrissionPage`

---
## 1.数据来源分析
**爬取的网址以及数据内容**
* 网址：https://www.douyin.com/video/7551701692555873575
* 分享链接：
    >1.07 复制打开抖音，看看【ChromaPulse的作品】这里是《星球大战》的取景地，也是名流们的度假天堂。... https://v.douyin.com/9x7fKjHOF4g/ o@q.eb rRK:/ 01/13 
    > 
    其中，https://v.douyin.com/9x7fKjHOF4g/ 为有效短链接
* 数据：视频/图片 （ *Live图为图片和视频合成* ）

---
## 2.抓包分析
**浏览器开发工具使用以及数据位置定位**
* 开发者工具
`F12 --> Network` 或 `网页空白处右键 --> Inspect --> Network`
* 网页刷新
* 关键字搜索定位数据位置
    * 通过 `Filters --> Media/Img` --> 点击过滤结果 --> `Headers --> Request URL` ，选取其中任意字段搜索（*详细定位方法见第 5节* ）

---
## 3.模块选择
**`requests`模块**
1. 发送请求：模拟浏览器对URL地址发送请求（*需对加密参数逆向解密，工程难度大*）
2. 获取数据：获取服务器返回响应数据
3. 解析数据：定位提取所需数据
4. 保存数据：将所需数据本地保存

**`DrissionPage`模块**

*自动化模块：模拟人类使用浏览器操作行为*

1. 打开浏览器，访问网页
2. 获取数据
3. 解析数据
4. 保存数据

*综上，使用* `DrissionPage` *模块获取解析数据，* `requests` *模块保存数据*

---
## 4.DrissionPage模块使用准备工作
>DrissionPage官方文档：https://www.drissionpage.cn/browser_control/intro

**浏览器路径设置以及启动测试**
```python
from DrissionPage import Chromium, ChromiumOptions

path = r'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'  # Chrome在电脑的可执行文件路径
ChromiumOptions().set_browser_path(path).save()

tab = Chromium().latest_tab
tab.get('https://www.youtube.com/')
```
*浏览器启动并打开网页表明测试成功，可以开始开发代码*

---
## 5.数据定位及解析
**数据定位**
* 主页
    * `Search` 关键词 `post/`
    * 在 `Headers` 中找到监听位置 `web/aweme/post/`
    * 数据解析 `Preview`


* 视频
    * `Search` 关键词 `detail/`
    * 在 `Headers` 中找到监听位置 `web/aweme/detail/`
    * 数据解析 `Preview`
        >`aweme_detail`
        >>`author`
        >>>`nickname` ：用户名
        >>>`unique_id` ：抖音号
        >>>`uid` ：数据库真实 ID
        >>>`sec_uid` ：加密的用户 ID，用于爬虫构造 URL
        >>
        >>`aweme_id` ：视频 ID
        >>`create_time` ：视频发布时间，使用 `datetime` 库转换
        >>`desc` ：视频文案
        >>`video`
        >>>`bit_rate` ：视频质量最全的 `video_info_list`
        >>>>`0`
        >>>>>`FPS`
        >>>>>`bit_rate`
        >>>>>`format`
        >>>>>`play_addr`
        >>>>>>`data_size`
        >>>>>>`file_hash` ：过滤重复视频
        >>>>>>`height`
        >>>>>>`width`
        >>>>>>`url_key` ：通过字段判断视频编码格式
        >>>>>>`url_list`
        >>>>
        >>>>`1`
        >>>>&nbsp;**⋮**
        >>>
        >>>`bit_rate_audio` ：值为 `null` 时无需音频合成
        >>>`cover` ：视频封面
        >>>`play_addr`
        >>>>`data_size`
        >>>>`file_hash`
        >>>>`height`
        >>>>`width`
        >>>>`url_key`
        >>>>`url_list`
        >>>
        >>>`play_addr_265`
        >>>`play_addr_h264`


* 图片
    * `Search` 关键词 `post/`
    * 在 `Headers` 中找到监听位置 `web/aweme/post/`
    * 数据解析 `Preview`


* Live图
    * `Search` 关键词 `post/`
    * 在 `Headers` 中找到监听位置 `web/aweme/post/`
    * 数据解析 `Preview`