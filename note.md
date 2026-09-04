# SaveTik流程

---
## 0. 环境准备
**安装Chrome浏览器**

**Python**
* `pip install requests` 和 `pip install DrissionPage`

---
## 1. 数据来源分析
**爬取的网址以及数据内容**
* 网址：https://www.douyin.com/video/7551701692555873575
* 分享链接：
    >1.07 复制打开抖音，看看【ChromaPulse的作品】这里是《星球大战》的取景地，也是名流们的度假天堂。... https://v.douyin.com/9x7fKjHOF4g/ o@q.eb rRK:/ 01/13 
    > 
    其中，https://v.douyin.com/9x7fKjHOF4g/ 为有效短链接
* 数据：视频/图片 （ *Live图为图片和视频合成* ）

---
## 2. 抓包分析
**浏览器开发工具使用以及数据位置定位**
* 开发者工具
`F12 --> Network` 或 `网页空白处右键 --> Inspect --> Network`
* 网页刷新
* 关键字搜索定位数据位置
    * 通过 `Filters --> Media/Img` --> 点击过滤结果 --> `Headers --> Request URL` ，选取其中任意字段搜索（*详细定位方法见第 5节* ）

---
## 3. 模块选择
**`requests` 模块**
1. 发送请求：模拟浏览器对URL地址发送请求（*需对加密参数逆向解密，工程难度大*）
2. 获取数据：获取服务器返回响应数据
3. 解析数据：定位提取所需数据
4. 保存数据：将所需数据本地保存

**`DrissionPage` 模块**

*自动化模块：模拟人类使用浏览器操作行为*

1. 打开浏览器，访问网页
2. 获取数据
3. 解析数据
4. 保存数据

*综上，使用* `DrissionPage` *模块获取解析数据，* `requests` *模块保存数据*

---
## 4. DrissionPage模块使用准备工作
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
## 5. 数据定位及解析
**数据定位**
* 主页
    * `Search` 关键词请求： `post/`
    * 在 `Headers` 中找到监听位置 `web/aweme/post/`
    * 数据解析 `Preview`


* 视频
    * `Search` 关键词请求： `detail/`
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
        >>>>>`HDR_bit` ：HDR 视频为 10
        >>>>>`HDR_type` ：HDR 视频为 1
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
        >>> `is_source_HDR`：值为 `1` 时用户上传的视频为HDR视频


* 图片
    * `Search` 关键词请求： `post/`
    * 在 `Headers` 中找到监听位置 `web/aweme/post/`
    * 数据解析 `Preview` ，详细解析同Live图，区别在于 `live_photo_type` 的值，且视频链接 `video` 字段不存在
    

* Live图
    * `Search` 关键词请求： `post/`
    * 在 `Headers` 中找到监听位置 `web/aweme/post/`
    * 数据解析 `Preview`
        > `aweme_list`
        >>`0` ：目标链接内容一般在第一个元素，其他元素为推荐内容
        >>>`author`
        >>>>`nickname` ：用户名
        >>>
        >>>`create_time` ：视频发布时间，使用 `datetime` 库转换
        >>>`images` 
        >>>>`0` ：目标链接第一张图片
        >>>>>`live_photo_type` ：Live图为 1
        >>>>>`height` ：图片高度
        >>>>>`width` ：图片宽度
        >>>>>`url_list` ：一般3个图片链接，前两个为 `.webp` 格式，最后一个为 `.jpeg` 格式
        >>>>>>`0`
        >>>>>>`1`
        >>>>>>`2` ：一般这个链接为 `.jpeg` 格式，URL解析从此处开始提高效率
        >>>>>
        >>>>>`video` ：Live图为图片和视频合成，视频链接在此处
        >>>>>>`bit_rate`
        >>>>>>>`0` ：一般只有一个质量的视频文件
        >>>>>>>>`play_addr`
        >>>>>>>>>`url_list` ：视频下载链接
        >>>>
        >>>>`1` ：目标链接第二张图片
        >>>>&nbsp;**⋮**
        >>>

    * 对于下载图片或者下载合成Live图，需要的是 `.jpeg` 格式的链接，因此需要通过 `url_list` 中最后一个链接进行下载，但为了保险起见，需要通过解析URL路径确定链接的格式是目标 `.jpeg` 格式，下面为示例代码：

        ```python
        from urllib.parse import urlparse

        url_list = aweme_list[0]['images'][0]['url_list']
        target_jpeg_url = None

        for url in reversed(url_list):
            parsed_path = urlparse(url).path
            if parsed_path.lower().endswith('.jpeg'):
                target_jpeg_url = url
                break

        if target_jpeg_url:
            #====================================#
            #  将 target_jpeg_url 传入对应数据接口  #
            #====================================#
            pass
        else:
            #==============#
            #  提示链接无效  #
            #==============#
            pass
        ```

* 置顶图片 / Live图
    * 服务端渲染（SSR）直出的 JSON 数据，不走单独的 API 请求
    * 在 `Network` 找到以作品长链接结尾 `<aweme_id>` 为名的 `Doc` 
    * 在其中定位 `\"awemeId\":\"<aweme_id>\"` 字段，解析出数据，构造为正常的 API 数据格式
---
## 6. 必要签名参数逆向
**以主页页面请求 `post/` 为例**
* 必要签名定位
    * 复制请求的 `cURL`
    * 使用在线工具，如：https://curlconverter.com/ 转换为 Python 代码
    * 调试参数定位必要签名参数

* `a_bogus` 参数逆向 **<sup>∗</sup>**
    * 在 `Source` 中 `XHR/fetch Breakpoints` 监听请求字段 `aweme/post/`
    * 刷新页面，触发断点后在 `Scope` 中找到 `_xhr_open_args` 参数
    * 确定 `_xhr_open_args.url` 参数上下文及内容，其中包含必要签名参数 `a_bogus` ,其值长度 >180
    * 在 `Call Stack` 中找到 `_xhr_open_args.url` 包含 `a_bogus` 参数在堆栈中出现的临界点，注意类似下面的示例代码（**bdms_x.x.x.x_fix.js**）：

        ```javascript
        var m = n.apply(d, e);
        ```
        * 将函数 `d` 作用于对象 `n` 上，传入参数 `e`，得到结果 `m`
    * 添加日志断点
        ```javascript
        "m", m, "n", n, "d", d, "e", e
        ```
    * 刷新页面，观察日志输出，发现 `e` 参数包含必要签名参数 `a_bogus` 的值
    * 关注上述示例代码所在函数 **function d( ) {...}** 中 `v[p]` 相关运算操作符 `+` `-` `*` `/` `%` `^` `&` `|` `<<` `>>` ，都添加日志断点，例：
        ```javascript
        "加法操作 >>> ", v[p], " +++ ", E, " === ", (v[p] + E)
        ```
    * `a_bogus` 每轮由四次 `e` 拼接，通过观察每次 `d` 的值为一个64位字符串，其为魔改的base64编码，将一段由4位短乱码和长乱码拼接的乱码进行编码为 `a_bogus`
    * `a_bogus` 拼接逆向 - 短乱码生成
        * 根据日志停止点附近 `a_bogus` 参数上端 `d` 中乱码值前4位（或 < 4位）字符所在位置（10,6000行附近），定位查找该段乱码第一次生成的位置（10,1000行附近，在log中在10,2000行附近位置有连续255 - 0减法操作，往上大概30次出现长日志），注意 `m` 的值为4的logpoint，再往上`m` 的值为短乱码第一次生成位置
        * `m` 为之前的 `e` 中4位数组作为参数传入函数生成，而该4位数组为随机数与掩码数通过运算符操作生成，将其本地化 `bdms_sgt.js`，注意观察日志输入参数和函数使用逻辑
    * `a_bogus` 拼接逆向 - 长乱码生成
        * 在10,2000行附近位置有连续255 - 0减法操作往下一系列 `m` 的值为211到 `m` 发生变化处（10,4000行附近），通过加法操作生成长乱码第一个字符
        
    * SM3算法逆向（32位数组）
        * 在输出日志中找到签名参数的变量，和传入该签名参数的函数 - SM3算法：签名参数 => 32位数组，（*也可直接在脚本* **bdms_x.x.x.x_fix.js** *中搜索* **key：“sum”** *找到其所在的函数* ）
        * 分析 `v[p] +` 日志断点中签名参数 `device_platform`, `spot_keys` + 盐值`dhzx`，以及 `m` 中32位数组
        * 将SM3算法本地化 `bdms_sm3.js` ，注意观察日志输入参数和函数使用逻辑，例
            > 分别传入签名参数以及盐值 `dhzx` ，加密两次，分别生成两个32位数组
    
---
**∗** `a_bogus` 参数为必要签名参数，缺失或错误会导致请求失败，（截止到 2026/03/05 00:40:00）

