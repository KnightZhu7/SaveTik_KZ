import customtkinter as ctk
from utils.video_parser import parse_video_data
from utils.video_downloader import download_video_stream
import threading

class SaveTikApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        # 窗口基础设置
        self.title("SaveTik - Douyin Downloader")
        self.geometry("700x550")
        self.configure(fg_color="#191919") # Notion 暗黑背景色
        
        # 风格配置
        self.accent_color = "#2EAADC" # Notion 蓝色
        self.card_bg = "#202020"
        self.border_color = "#373737"
        self.text_main = "#D3D3D3"
        
        # 布局权重
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(2, weight=1)

        # 标题
        self.header_label = ctk.CTkLabel(
            self, 
            text="📥 SaveTik_KZ", 
            font=("Inter", 28, "bold"), 
            text_color="#FFFFFF"
        )
        self.header_label.grid(row=0, column=0, pady=(40, 20))

        # 输入区域
        self.input_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.input_frame.grid(row=1, column=0, sticky="ew", padx=60)
        self.input_frame.grid_columnconfigure(0, weight=1)

        self.url_entry = ctk.CTkEntry(
            self.input_frame, 
            placeholder_text="粘贴抖音视频分享链接...", 
            height=42, 
            fg_color=self.card_bg, 
            border_color=self.border_color,
            text_color=self.text_main,
            corner_radius=8
        )
        self.url_entry.grid(row=0, column=0, sticky="ew", padx=(0, 12))

        self.fetch_btn = ctk.CTkButton(
            self.input_frame, 
            text="获取视频", 
            width=100, 
            height=42,
            fg_color=self.accent_color,
            hover_color="#1E88B5",
            font=("Inter", 13, "bold"),
            corner_radius=8,
            command=self.on_fetch
        )
        self.fetch_btn.grid(row=0, column=1)

        # 结果滚动列表
        self.scroll_frame = ctk.CTkScrollableFrame(
            self, 
            fg_color="transparent", 
            scrollbar_button_color=self.border_color,
            scrollbar_button_hover_color="#454545"
        )
        self.scroll_frame.grid(row=2, column=0, sticky="nsew", padx=60, pady=20)
        
        # 状态栏
        self.status_bar = ctk.CTkLabel(
            self, 
            text="准备就绪", 
            font=("Inter", 12), 
            text_color="#888888"
        )
        self.status_bar.grid(row=3, column=0, pady=(0, 15))

        self.video_data = []
        self.metadata = {}

    def on_fetch(self):
        url = self.url_entry.get().strip()
        if not url: return

        self.fetch_btn.configure(state="disabled", text="解析中...")
        self.status_bar.configure(text="正在解析视频数据，请稍候...")
        
        # 清空列表
        for widget in self.scroll_frame.winfo_children():
            widget.destroy()

        def do_parse():
            try:
                data, meta = parse_video_data(url)
                self.after(0, lambda: self.render_list(data, meta))
            except Exception as e:
                self.after(0, lambda: self.status_bar.configure(text=f"解析出错: {e}"))
                self.after(0, lambda: self.fetch_btn.configure(state="normal", text="获取视频"))

        threading.Thread(target=do_parse, daemon=True).start()

    def render_list(self, data, meta):
        self.fetch_btn.configure(state="normal", text="获取视频")
        if not data:
            self.status_bar.configure(text="未解析到有效视频流")
            return

        self.video_data = data
        self.metadata = meta
        self.status_bar.configure(text=f"👤 {meta['nickname']}  |  📅 {meta['create_time']}")

        for info in data:
            item = ctk.CTkFrame(
                self.scroll_frame, 
                fg_color=self.card_bg, 
                border_width=1, 
                border_color=self.border_color,
                corner_radius=8
            )
            item.pack(fill="x", pady=6)
            
            desc = f"🎬 {info['width']}x{info['height']}  |  {info['encoding']}  |  {info['bit_rate']} bps"
            ctk.CTkLabel(item, text=desc, font=("Inter", 13), text_color=self.text_main).pack(side="left", padx=20, pady=12)
            
            dl_btn = ctk.CTkButton(
                item, 
                text="下载", 
                width=70, 
                height=28, 
                fg_color="#373737", 
                hover_color="#454545",
                font=("Inter", 12, "bold"),
                command=lambda i=info: self.on_download(i)
            )
            dl_btn.pack(side="right", padx=20)

    def on_download(self, info):
        self.status_bar.configure(text=f"正在下载 {info['height']}p 视频...")
        threading.Thread(target=download_video_stream, args=(info, self.metadata), daemon=True).start()

if __name__ == "__main__":
    app = SaveTikApp()
    app.mainloop()