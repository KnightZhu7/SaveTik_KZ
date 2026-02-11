This is a simple and efficient Douyin web video downloader built on `DrissionPage`.

## Features
- Cross-platform support:
   - macOS: Native **SwiftUI** interface for a modern and smooth user experience
   - Windows: Python-based GUI built with `customtkinter`
   - Consistent core logic and downloading behavior across platforms
<br>
- Download videos from the Douyin web platform with comprehensive quality selection support:
  - **Resolution** (e.g. 720p / 1080p / 4K)
  - **Bitrate** (Choose the required bitrate)
  - **Video Codec** (H.264 / H.265)
  - **HDR Support** (HDR10 / SDR)
  
  The tool automatically retrieves all available quality profiles for a target video, allowing you to precisely select and download the desired version.

## Interface Preview (Mac)

![SaveTik_KZ UI Dark](Image/Preview%20Dark.png)


## Requirements

- Python 3.6+
- A web browser (Chromium-based browsers are supported by default in DrissionPage)
- Xcode

## Quick Start

**Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

**Run**:
   ```bash
   python main.py
   ```

**Package the application**:
   ```bash
   python package_app.py
   ```