import customtkinter as ctk
from utils.video_parser import parse_video_data
from utils.video_downloader import download_video_stream
import threading
from utils.browser_helper import init_browser_config
# from PIL import Image # 用于处理图标

class SaveTikApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        # 窗口基础设置
        self.title("SaveTik_KZ - Douyin Video Downloader")
        self.geometry("700x550")
        self.configure(fg_color="#191919") # Notion 暗黑背景色
        
        # 风格配置
        self.accent_color = "#2EAADC" # Notion 蓝色
        self.card_bg = "#202020"
        self.border_color = "#373737"
        self.text_main = "#D3D3D3"
        
        # 加载图标 (如果以后你有图标文件，可以取消注释并替换路径)
        # self.paste_icon = ctk.CTkImage(light_image=Image.open("paste.png"), 
        #                               dark_image=Image.open("paste.png"), 
        #                               size=(20, 20))
        # self.clear_icon = ctk.CTkImage(light_image=Image.open("clear.png"), 
        #                               dark_image=Image.open("clear.png"), 
        #                               size=(20, 20))

        # 变量与状态
        self.url_var = ctk.StringVar()
        self.checkbox_vars = []

        # 布局权重
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(3, weight=1)

        # 标题
        self.header_label = ctk.CTkLabel(
            self, 
            text="SaveTik_KZ", 
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
            corner_radius=8,
            textvariable=self.url_var
        )
        self.url_entry.grid(row=0, column=0, sticky="ew", padx=(0, 12))
        self.url_entry.bind("<Return>", lambda e: self.on_fetch())

        self.fetch_btn = ctk.CTkButton(
            self.input_frame, 
            text="获取视频", 
            width=100, 
            height=42,
            fg_color=self.accent_color,
            hover_color="#1E88B5",
            font=("Inter", 13, "bold"),
            corner_radius=8,
            command=self.on_action_btn_click
        )
        self.fetch_btn.grid(row=0, column=1)

        # 批量下载与选择区域
        self.selection_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.selection_frame.grid(row=2, column=0, sticky="ew", padx=60, pady=(10, 0))
        
        # 左侧：全选和计数
        self.select_all_btn = ctk.CTkButton(
            self.selection_frame,
            text="全选",
            width=60,
            height=32,
            fg_color="#373737",
            hover_color="#454545",
            font=("Inter", 12, "bold"),
            corner_radius=6,
            command=self.on_select_all,
            state="disabled"
        )
        self.select_all_btn.pack(side="left")

        self.deselect_btn = ctk.CTkButton(
            self.selection_frame,
            text="取消",
            width=60,
            height=32,
            fg_color="#373737",
            hover_color="#454545",
            font=("Inter", 12, "bold"),
            corner_radius=6,
            command=self.on_deselect_all,
            state="disabled"
        )
        self.deselect_btn.pack(side="left", padx=10)
        
        self.selected_count_label = ctk.CTkLabel(
            self.selection_frame,
            text="已选 0 个",
            font=("Inter", 12),
            text_color="#888888"
        )
        self.selected_count_label.pack(side="left", padx=15)

        # 右侧：下载按钮
        self.download_btn = ctk.CTkButton(
            self.selection_frame,
            text="下载选中视频",
            width=120,
            height=32,
            fg_color=self.accent_color,
            hover_color="#1E88B5",
            font=("Inter", 12, "bold"),
            corner_radius=6,
            command=self.on_download_selected,
            state="disabled"
        )
        self.download_btn.pack(side="right")

        # 结果滚动列表
        self.scroll_frame = ctk.CTkScrollableFrame(
            self, 
            fg_color="transparent", 
            scrollbar_button_color=self.border_color,
            scrollbar_button_hover_color="#454545"
        )
        self.scroll_frame.grid(row=3, column=0, sticky="nsew", padx=60, pady=20)
        
        # 状态栏
        self.status_bar = ctk.CTkLabel(
            self, 
            text="准备就绪", 
            font=("Inter", 12), 
            text_color="#888888"
        )
        self.status_bar.grid(row=4, column=0, pady=(0, 15))

        self.video_data = []
        self.metadata = {}

    def on_list_scroll(self, event):
        """当滚动发生时，重置所有未选中条目的颜色，防止悬停色残留 (由 item 触发)"""
        for var, info, item in self.checkbox_vars:
            if not var.get():
                item.configure(fg_color=self.card_bg)

    def update_selection_ui(self):
        """更新全选按钮文字和选中计数"""
        if not self.checkbox_vars:
            self.selected_count_label.configure(text="已选 0 个")
            self.select_all_btn.configure(state="disabled")
            self.deselect_btn.configure(state="disabled")
            self.download_btn.configure(state="disabled")
            return

        selected_count = sum(1 for var, info, item in self.checkbox_vars if var.get())
        total_count = len(self.checkbox_vars)
        
        self.selected_count_label.configure(text=f"已选 {selected_count} 个")
        self.select_all_btn.configure(state="normal" if selected_count < total_count else "disabled")
        self.deselect_btn.configure(state="normal" if selected_count > 0 else "disabled")
        self.download_btn.configure(state="normal" if selected_count > 0 else "disabled")

    def on_select_all(self):
        """全选所有视频"""
        if not self.checkbox_vars: return
        for var, info, item in self.checkbox_vars:
            var.set(True)
        self.update_selection_ui()

    def on_deselect_all(self):
        """取消所有选择"""
        if not self.checkbox_vars: return
        for var, info, item in self.checkbox_vars:
            var.set(False)
        self.update_selection_ui()

    def on_action_btn_click(self):
        """处理获取/清除按钮点击"""
        if self.fetch_btn.cget("text") == "✕ 清除":
            # 清除逻辑
            self.url_var.set("")
            self.url_entry.focus()
            # 恢复为获取按钮样式
            self.fetch_btn.configure(text="📋 获取视频", fg_color=self.accent_color, hover_color="#1E88B5")
        else:
            # 获取视频逻辑
            url = self.url_var.get().strip()
            if not url:
                # 如果输入框为空，尝试从剪切板获取内容
                try:
                    clipboard_content = self.root.clipboard_get() if hasattr(self, 'root') else self.clipboard_get()
                    if clipboard_content:
                        self.url_var.set(clipboard_content)
                        url = clipboard_content
                except:
                    pass
            
            if url:
                self.on_fetch()

    def on_fetch(self):
        url = self.url_var.get().strip()
        if not url: return

        self.fetch_btn.configure(state="disabled", text="解析中...")
        self.status_bar.configure(text="正在解析视频数据，请稍候...", text_color="#888888")
        
        # 清空列表
        for widget in self.scroll_frame.winfo_children():
            widget.destroy()
        self.checkbox_vars = []
        self.select_all_btn.configure(state="disabled")
        self.deselect_btn.configure(state="disabled")
        self.selected_count_label.configure(text="已选 0 个")
        self.download_btn.configure(state="disabled")

        def do_parse():
            try:
                data, meta = parse_video_data(url)
                self.after(0, lambda: self.render_list(data, meta))
            except Exception as e:
                self.after(0, lambda: self.status_bar.configure(text=f"{e}", text_color="#FF5555"))
                # 解析失败也切换到清除状态，方便用户清空错误链接
                self.after(0, lambda: self.fetch_btn.configure(text="✕ 清除", fg_color="#373737", hover_color="#454545", state="normal"))

        threading.Thread(target=do_parse, daemon=True).start()

    def render_list(self, data, meta):
        # 解析成功后，将按钮切换为清除状态
        self.fetch_btn.configure(text="✕ 清除", fg_color="#373737", hover_color="#454545", state="normal")

        self.video_data = data
        self.metadata = meta
        self.status_bar.configure(text=f"解析完成: {len(data)} 个视频流", text_color="#888888")
        self.select_all_btn.configure(state="normal")
        self.deselect_btn.configure(state="normal")

        for info in data:
            item = ctk.CTkFrame(
                self.scroll_frame, 
                fg_color=self.card_bg, 
                border_width=1, 
                border_color=self.border_color,
                corner_radius=8
            )
            item.pack(fill="x", pady=6)
            
            # 勾选框变量
            var = ctk.BooleanVar(value=False)
            
            # 右侧操作按钮 (未选中时为下载，选中时为勾选状态)
            action_btn = ctk.CTkButton(
                item, 
                text="下载", 
                width=60, 
                height=28, 
                font=("Inter", 12, "bold"),
                corner_radius=6
            )
            action_btn.pack(side="right", padx=20)

            # 颜色与按钮状态反馈逻辑
            def update_item_style(*args, v=var, f=item, btn=action_btn, i=info):
                if v.get():
                    f.configure(fg_color="#333333", border_color="#4a4a4a")
                    btn.configure(text="✓", fg_color=self.accent_color, hover_color="#1E88B5", command=lambda: v.set(False))
                else:
                    f.configure(fg_color=self.card_bg, border_color=self.border_color)
                    btn.configure(text="下载", fg_color="#373737", hover_color="#454545", command=lambda: self.on_download_individual(i))
                self.update_selection_ui()
            
            var.trace_add("write", update_item_style)
            update_item_style() # 初始化按钮状态

            # 定义切换勾选状态的函数
            def on_hover(entering, f=item, v=var):
                if not v.get(): # 仅在未选中时显示悬停色
                    f.configure(fg_color="#282828" if entering else self.card_bg)

            def toggle_selection(event, v=var):
                v.set(not v.get())
            
            # 绑定悬停和点击事件
            item.bind("<Enter>", lambda e, h=on_hover: h(True))   # 鼠标移入：显示悬停色
            item.bind("<Leave>", lambda e, h=on_hover: h(False))  # 鼠标移出：恢复背景色
            item.bind("<Button-1>", toggle_selection)             # 左键点击：切换选中状态
            item.bind("<MouseWheel>", self.on_list_scroll)        # 滚轮滚动：防止悬停色残留 (Windows/macOS)
            item.bind("<Button-4>", self.on_list_scroll)          # 滚轮向上：同上 (Linux)
            item.bind("<Button-5>", self.on_list_scroll)          # 滚轮向下：同上 (Linux)
            
            self.checkbox_vars.append((var, info, item))

            is_hdr = info.get('HDR_bit') == "10" and info.get('HDR_type') == "1"
            
            # 创建信息容器以实现对齐
            info_container = ctk.CTkFrame(item, fg_color="transparent")
            info_container.pack(side="left", padx=20, pady=12)
            
            # 定义列配置: (内容, 宽度)
            cols = [
                (f"🎬 {info['width']}x{info['height']}", 110),
                (f"{info['fps']} FPS", 70),
                (f"{info['encoding']}", 70),
                (f"{info['bit_rate']} bps", 110),
                ("HDR" if is_hdr else "", 60)
            ]

            for text, w in cols:
                lbl = ctk.CTkLabel(
                    info_container, 
                    text=text, 
                    font=("Inter", 13), 
                    text_color=self.text_main,
                    width=w,
                    anchor="w"
                )
                lbl.pack(side="left")
                # 绑定事件到每个 Label
                lbl.bind("<Enter>", lambda e, h=on_hover: h(True))
                lbl.bind("<Leave>", lambda e, h=on_hover: h(False))
                lbl.bind("<Button-1>", toggle_selection)
                lbl.bind("<MouseWheel>", self.on_list_scroll)
                lbl.bind("<Button-4>", self.on_list_scroll)
                lbl.bind("<Button-5>", self.on_list_scroll)

            # 也要给容器绑定事件，防止标签间的间隙不触发
            info_container.bind("<Enter>", lambda e, h=on_hover: h(True))
            info_container.bind("<Leave>", lambda e, h=on_hover: h(False))
            info_container.bind("<Button-1>", toggle_selection)
            info_container.bind("<MouseWheel>", self.on_list_scroll)
            info_container.bind("<Button-4>", self.on_list_scroll)
            info_container.bind("<Button-5>", self.on_list_scroll)

    def on_download_individual(self, info):
        """下载单个视频"""
        self.status_bar.configure(text="正在准备下载...", text_color="#888888")
        
        def do_download():
            is_hdr = info.get('HDR_bit') == "10" and info.get('HDR_type') == "1"
            hdr_tag = " HDR" if is_hdr else ""
            self.after(0, lambda: self.status_bar.configure(text=f"⏳ 正在下载: {info['width']}p{hdr_tag}..."))
            
            if download_video_stream(info, self.metadata):
                self.after(0, lambda: self.status_bar.configure(text=f"✅ 下载完成: {info['width']}p{hdr_tag}", text_color="#888888"))
            else:
                self.after(0, lambda: self.status_bar.configure(text=f"❌ 下载失败: {info['width']}p{hdr_tag}", text_color="#888888"))

        threading.Thread(target=do_download, daemon=True).start()

    def on_download_selected(self):
        """批量下载选中的视频"""
        selected_infos = [info for var, info, item in self.checkbox_vars if var.get()]
        if not selected_infos:
            self.status_bar.configure(text="⚠️ 请先勾选需要下载的视频", text_color="#888888")
            return

        self.download_btn.configure(state="disabled", text="正在下载...")
        
        def do_batch_download():
            total = len(selected_infos)
            success_count = 0
            failed_items = []
            for i, info in enumerate(selected_infos, 1):
                is_hdr = info.get('HDR_bit') == "10" and info.get('HDR_type') == "1"
                hdr_tag = " HDR" if is_hdr else ""
                self.after(0, lambda i=i, w=info['width'], t=hdr_tag: 
                           self.status_bar.configure(text=f"⏳ 正在下载 ({i}/{total}): {w}p{t}...", text_color="#888888"))
                
                if download_video_stream(info, self.metadata):
                    success_count += 1
                else:
                    failed_items.append(f"{info['width']}p{hdr_tag}")
            
            if success_count == total:
                self.after(0, lambda: self.status_bar.configure(
                    text=f"✅ 下载完成: 成功 {success_count}/{total}", 
                    text_color="#888888"
                ))
            elif success_count == 0:
                self.after(0, lambda: self.status_bar.configure(
                    text=f"❌ 下载失败: 选中的 {total} 个视频均下载失败", 
                    text_color="#888888"
                ))
            else:
                self.after(0, lambda: self.status_bar.configure(
                    text=f"⚠️ 部分下载成功: {success_count}/{total} (失败: {', '.join(failed_items)})", 
                    text_color="#888888"
                ))
            
            self.after(0, lambda: self.download_btn.configure(state="normal", text="下载选中视频"))

        threading.Thread(target=do_batch_download, daemon=True).start()

if __name__ == "__main__":
    init_browser_config()
    app = SaveTikApp()
    app.mainloop()