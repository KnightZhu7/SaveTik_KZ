<p align="center">
  <img src="Image/macOS_Icon_KZ_Blurred.png" width="120" />
</p>

<h1 align="center">SaveTik_KZ</h1>
</p>

This is a simple and efficient Douyin web video downloader built on `DrissionPage`.

---
## Features
- Cross-platform support:
   - macOS: Native **SwiftUI** interface for a modern and smooth user experience
   - Windows: Python-based GUI built with `customtkinter`
   - Consistent core logic and downloading behavior across platforms

- Download videos from the Douyin web platform with comprehensive quality selection support:
  - **Resolution** (e.g. 720p / 1080p / 4K)
  - **Bitrate** (Choose the required bitrate)
  - **Video Codec** (H.264 / H.265)
  - **HDR Support** (HDR10 / SDR)
  
  The tool automatically retrieves all available quality profiles for a target video, allowing you to precisely select and download the desired version.

## Interface Preview (Mac)

<p align="center">
  <img src="Image/Preview%20Dark%20New%201.png" width="600">
</p>
<p align="center">
  <a href="https://github.com/KnightZhu7/SaveTik_KZ/releases/latest">Download Latest Release</a>
</p>

---
## Requirements

- Python 3.6+
- Chrome
- Xcode

## Quick Start (Windows)

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