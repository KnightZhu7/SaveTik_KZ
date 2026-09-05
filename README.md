<p align="center">
  <img src="Image/macOS_Icon_KZ_Blurred.png" width="120" />
</p>

<h1 align="center">SaveTik_KZ</h1>

<p align="center">
  A cross-platform Douyin content downloader for macOS and Windows
</p>

---

## Features

### Cross-platform Support
- **macOS**: Native **SwiftUI** interface for a modern and smooth user experience  
- **Windows**: Python-based GUI built with `customtkinter`  
- Shared core downloading logic powered by `DrissionPage`

---

### Video Downloading
Download Douyin web videos with comprehensive quality selection support:

- **Resolution** (e.g. 720p / 1080p / 4K)
- **Bitrate** (select the preferred bitrate)
- **Video Codec** (H.264 / H.265)
- **HDR Support** (HDR10 / SDR)

The tool automatically retrieves all available quality profiles for a target video, allowing precise selection before downloading.

#### macOS Exclusive Enhancements
- **Advanced quality filtering** for quickly narrowing down available video versions by resolution and codec

---

### Douyin Image Post Support (macOS Only)
Supports Douyin image-post links:

- Download and save `JPEG` images
- Save **Live Photos** directly into the macOS **Photos app**

---

## Interface Preview (Mac)

<p align="center">
  <img src="Image/Preview%20Dark%20New%201.png" width="400" />
  <img src="Image/Preview%20Light%20New.png" width="400" />
</p>

<p align="center">
  <a href="https://github.com/KnightZhu7/SaveTik_KZ/releases/tag/V1.5.7">
    Download Latest Release
  </a>
</p>

<p align="center">
  Fully Native macOS Version
  &nbsp;—&nbsp;
  <a href="https://github.com/KnightZhu7/SaveTik_KZ-f2">
    SaveTik_KZ-f2
  </a>
</p>

---

## Requirements

- Python 3.6+
- Chrome
- Xcode

---

## Quick Start (Windows)

### Install dependencies
```bash
pip install -r requirements.txt
```

### Run
```bash
python main.py
```

### Package the application
```bash
python package_app.py
```