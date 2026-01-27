This is a simple and efficient Douyin web video downloader built on `DrissionPage`.

## Features

- Download videos from the Douyin web platform with support for multiple quality options.  
  This tool retrieves all available video quality levels for a target video, allowing you to select and download the quality you need.

- Currently, selecting a specific video quality involves running `print_video_list.py` to list available options. After reviewing the output, you need to adjust the corresponding settings in `video_downloader.py` under the utils directory and then execute `main.py`. The video will be downloaded in the selected quality. You can read `note.md` for more details about the project’s underlying mechanism.

## Requirements

- Python 3.6+
- A web browser (Chromium-based browsers are supported by default in DrissionPage)

## Quick Start

**Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

**Run**:
   ```bash
   python main.py
   ```
