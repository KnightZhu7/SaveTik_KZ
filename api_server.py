import uvicorn
import os
import sys
import uuid
import argparse
import threading # 1. 确保导入了 threading
from fastapi import FastAPI, BackgroundTasks, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import time

TASK_EXPIRY_SECONDS = 300

def set_task_status(task_id, status):
    tasks_db[task_id] = (status, time.time())

def get_task_status(task_id):
    entry = tasks_db.get(task_id)
    if not entry:
        return None
    status, ts = entry
    if time.time() - ts > TASK_EXPIRY_SECONDS:
        del tasks_db[task_id]
        return None
    return status

def cleanup_expired_tasks():
    """清理过期任务，防止字典无限膨胀"""
    now = time.time()
    expired = [k for k, (_, ts) in tasks_db.items()
               if now - ts > TASK_EXPIRY_SECONDS]
    for k in expired:
        del tasks_db[k]

# 导入你的工具类
from utils.video_parser import parse_video_data, force_release_mac_memory
from utils.video_downloader import download_video_stream
from utils.browser_helper import init_browser_config

# --- 路径处理函数 ---
def resource_path(relative_path):
    """
    获取资源文件的绝对路径，兼容 PyInstaller 打包后的情况
    """
    try:
        # PyInstaller 创建临时文件夹，并把路径存储在 _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

app = FastAPI(title="SaveTik_KZ API")

# 启用 CORS，允许 SwiftUI 客户端访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 数据模型 ---

class ParseRequest(BaseModel):
    url: str

class DownloadRequest(BaseModel):
    stream_info: Dict[str, Any]
    metadata: Dict[str, Any]

# --- 内存数据库存储任务状态 ---
tasks_db = {}

# --- 🔥 修改点 1: 新增健康检查接口 ---
# Swift 端会先 ping 这个接口，收到 200 OK 就变绿灯
@app.get("/")
async def health_check():
    return {"status": "ok", "message": "Backend is ready"}

# --- 🔥 修改点 2: 启动事件改为异步线程 ---
@app.on_event("startup")
async def startup_event():
    """服务器启动时初始化"""
    print("[*] HTTP服务已启动，正在后台线程初始化浏览器配置...")
    
    # 定义一个内部函数来执行耗时操作
    def run_init_in_background():
        try:
            # 这里执行你的耗时操作
            init_browser_config()
            print("[+] 浏览器配置后台初始化完成！")
        except Exception as e:
            print(f"[!] 初始化失败 (非致命): {e}")

    # 创建并启动守护线程
    # 这样 uvicorn 不会等 init_browser_config 跑完才开始监听端口
    # Swift 可以立刻连上端口，而浏览器配置在后台慢慢跑
    init_thread = threading.Thread(target=run_init_in_background)
    init_thread.daemon = True 
    init_thread.start()

# --- 核心接口 ---

@app.post("/parse")
async def parse_video(request: ParseRequest):
    """
    解析接口
    """
    print(f"[*] 收到解析请求: {request.url}")
    
    try:
        # 1. 调用解析逻辑 (增加 try-except 防止崩溃)
        streams, metadata = parse_video_data(request.url)
        
        # 2. 预处理数据给 SwiftUI
        for s in streams:
            # 安全处理 HDR 逻辑 (转成字符串再比较，防止 int/str 不一致)
            hdr_bit = str(s.get('HDR_bit', ''))
            hdr_type = str(s.get('HDR_type', ''))
            s['is_hdr'] = (hdr_bit == "10") and (hdr_type == "1")
            
            # 确保 fps 字段存在
            if 'fps' not in s:
                s['fps'] = s.get('FPS', '')
                
        return {
            "status": "success",
            "data": {
                "streams": streams,
                "metadata": metadata
            }
        }
        
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"[!] 解析发生内部错误: {e}")
        # 直接返回异常信息，方便前端展示具体的错误提示（如：该链接不是有效的视频链接）
        raise HTTPException(status_code=400, detail=str(e))

def run_download_task(task_id: str, stream_info: Dict, metadata: Dict):
    """后台执行下载 (增加异常捕获)"""
    # try:
    #     tasks_db[task_id] = "downloading"
    #     success = download_video_stream(stream_info, metadata)
    #     tasks_db[task_id] = "completed" if success else "failed"
    #     print(f"[*] 任务 {task_id} 结束，结果: {tasks_db[task_id]}")
    # except Exception as e:
    #     print(f"[!] 下载任务崩溃: {e}")
    #     tasks_db[task_id] = "failed"
    try:
        set_task_status(task_id, "downloading")
        success = download_video_stream(stream_info, metadata)
        set_task_status(task_id, "completed" if success else "failed")
    except Exception as e:
        print(f"[!] 下载任务崩溃: {e}")
        set_task_status(task_id, "failed")

@app.post("/download")
async def trigger_download(request: DownloadRequest, background_tasks: BackgroundTasks):
    task_id = str(uuid.uuid4())
    # tasks_db[task_id] = "pending"
    set_task_status(task_id, "pending")
    cleanup_expired_tasks()
    
    background_tasks.add_task(run_download_task, task_id, request.stream_info, request.metadata)
    
    return {"task_id": task_id}

@app.get("/status/{task_id}")
async def check_status(task_id: str):
    # status = tasks_db.get(task_id)
    status = get_task_status(task_id)
    if not status:
        raise HTTPException(status_code=404, detail="任务不存在")
    return {"task_id": task_id, "status": status}

@app.post("/clear")
async def clear_memory():
    """彻底清空任务记录并强制释放内存"""
    # 1. 清空下载任务字典（防止字典无限膨胀）
    cleared_count = len(tasks_db)
    tasks_db.clear()
    
    # 2. 触发 Python 的深度内存释放（归还 macOS 内存）
    force_release_mac_memory()
    
    print(f"[*] 前端触发清除：清理了 {cleared_count} 个任务状态，内存已释放。")
    return {"status": "success"}

# --- 启动入口 ---

if __name__ == "__main__":
    # 1. 初始化参数解析器
    parser = argparse.ArgumentParser(description="SaveTik_KZ Backend Server")
    
    # 2. 添加 --port 参数，默认 8000
    # Swift 端启动时会传入: ./api_server --port 54321
    parser.add_argument("--port", type=int, default=8000, help="Port to run the server on")
    
    # 3. 解析参数
    args = parser.parse_args()
    
    print(f"🚀 后端服务启动中... 监听端口: {args.port}")
    
    # 4. 启动 uvicorn
    try:
        uvicorn.run(app, host="127.0.0.1", port=args.port)
    except Exception as e:
        print(f"❌ 启动失败: {e}")