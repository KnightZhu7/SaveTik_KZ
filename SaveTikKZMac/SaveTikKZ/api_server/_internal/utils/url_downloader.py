import requests as req
def download_file(url: str, filename: str):
    """
    下载文件并保存到本地
    :param url: 文件的URL地址
    :param filename: 保存的文件名
    """
    response = req.get(url)
    with open(filename, 'wb') as f:
        f.write(response.content)