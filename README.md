This is a simple and efficient Douyin web video downloader built on `DrissionPage`.

## Features
- Cross-platform support:
   - Fully supported on macOS and Windows
   - Consistent behavior across platforms

- Download videos from the Douyin web platform with comprehensive quality selection support:
  - **Resolution** (e.g. 720p / 1080p / 4K)
  - **Bitrate** (Choose the required bitrate)
  - **Video Codec** (H.264 / H.265)
  - **HDR Support** (HDR10 / SDR)
  
  The tool automatically retrieves all available quality profiles for a target video, allowing you to precisely select and download the desired version.

## Interface Preview

![SaveTik_KZ UI](Screenshot%20SaveTik_KZ.png)


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

**Package the application**
   ```bash
   python package_app.py
   ```