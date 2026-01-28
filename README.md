This is a simple and efficient Douyin web video downloader built on `DrissionPage`.

## Interface Preview

![SaveTik_KZ UI](Screenshot%20SaveTik_KZ.png)

## Features

- Download videos from the Douyin web platform with comprehensive quality selection support:
  - **Resolution** (e.g. 720p / 1080p / 4K)
  - **Bitrate** (controls compression level and output quality)
  - **Video Codec** (such as H.264 / H.265)
  - **HDR Support** (HDR / SDR variants)
  
  The tool automatically retrieves all available quality profiles for a target video, allowing you to precisely select and download the desired version.


## Requirements

- Python 3.6+
- A web browser (Chromium-based browsers are supported by default in DrissionPage)

## Quick Start

**Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

**Set DerisionPage**:
   Edit the Chrome executable path in `set_drissionpage.py`
   ```bash
   python set_drissionpage.py
   ```

**Run**:
   ```bash
   python main.py
   ```

