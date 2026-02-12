//
//  ContentView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/3/26.
//

import SwiftUI

// MARK: - 0. 样式与主题配置
struct AppTheme {
    static let accentBlue = Color(red: 0.18, green: 0.66, blue: 0.86)
    
    static func backgroundColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(nsColor: .windowBackgroundColor)
    }
    
    static func cardColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.125, green: 0.125, blue: 0.125) : Color.white
    }
    
    static func borderColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.215, green: 0.215, blue: 0.215) : Color(nsColor: .separatorColor)
    }
    
    static func hoverColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.16) : Color(nsColor: .controlBackgroundColor)
    }
}

// MARK: - 1. 外观模式枚举
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色模式"
    case dark = "深色模式"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    
    // 关键：System 返回 nil，SwiftUI 才会把控制权交还给系统
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - 2. 下载log
// 日志类型，决定颜色和图标
enum LogType {
    case info, success, error, loading, connect // 🔥 新增 connect
    
    var color: Color {
        switch self {
        case .info: return .secondary
        case .connect: return AppTheme.accentBlue   // 🔥 连接中用蓝色
        case .loading: return AppTheme.accentBlue
        case .success: return .green
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"                    // 准备就绪：圆圈 i
        case .connect: return "globe"                       // 🔥 连接中：地球
        case .loading: return "arrow.triangle.2.circlepath" // 下载中：循环箭头
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

// 日志模型
struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let type: LogType
    let time = Date()
    
    // 格式化时间显示 (例如 12:30:05)
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: time)
    }
}

// NSViewRepresentable 包装原生 NSTextField
struct FixedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    @FocusState.Binding var isFocused: Bool  // 🔥 新增：接收焦点状态
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 13)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        
        // 设置为可滚动的单行模式
        if let cell = textField.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.wraps = false
            cell.isScrollable = true
        }
        
        // 🔥 监听获得焦点事件
        NotificationCenter.default.addObserver(
            forName: NSControl.textDidBeginEditingNotification,
            object: textField,
            queue: .main
        ) { notification in
            // 当获得焦点时，将光标移到末尾
            DispatchQueue.main.async {
                if let fieldEditor = textField.currentEditor() as? NSTextView {
                    let length = fieldEditor.string.count
                    fieldEditor.setSelectedRange(NSRange(location: length, length: 0))
                }
            }
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FixedTextField
        
        init(_ parent: FixedTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - 3. 主视图
struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appAppearance") private var selectedAppearance: AppAppearance = .system
    
    
    // --- 核心数据状态 ---
    @State private var urlInput: String = ""
    @State private var isFetching: Bool = false
    @State private var videoList: [VideoStream] = []
    @State private var selectedVideos: Set<UUID> = []
    
    // 🔥 新增：暂存 Python 解析回来的元数据 (作者、发布时间、文案等)
    // 只有存下来，下载时发回去，文件名才能包含这些信息
    @State private var currentMetadata: [String: String] = [:]
    
    // --- 底部状态栏控制 ---
    @State private var statusMessage: String = "准备就绪"
    @State private var statusIcon: String = "info.circle"     // 动态图标
    @State private var statusColor: Color = .secondary        // 动态颜色
    
    // 
    @State private var logs: [LogEntry] = [] // 存储所有日志
    @State private var showLogPopover: Bool = false // 控制弹窗显示
    //
    @State private var isBackendOnline: Bool = false
    @State private var startupAttempts: Int = 0
    @State private var hasError: Bool = false
    @FocusState private var isInputFocused: Bool
    @State private var textFieldID = UUID()
    // --- 批量下载追踪 ---
    @State private var activeTasksCount: Int = 0      // 正在进行的任务数
//    @State private var batchSuccessCount: Int = 0    // 成功计数
//    @State private var batchErrorCount: Int = 0      // 失败计数
    @State private var batchTotal = 0        // 本次选中的总数
    @State private var batchSuccess = 0      // 已成功的数量
    @State private var batchError = 0        // 已失败的数量
    
    // --- 计算属性 ---
    var isSelectionMode: Bool {
        !selectedVideos.isEmpty
    }
    
    var isAllSelected: Bool {
        !videoList.isEmpty && selectedVideos.count == videoList.count
    }
    
    var hasResults: Bool {
        !videoList.isEmpty
    }
    
    var shouldShowClearButton: Bool {
        hasResults || hasError // 如果有结果或者报错了，都应该显示“清除”
    }
    
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor(for: colorScheme).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                ZStack(alignment: .top) {
                                    
                                    // 1. 左上角的三个点按钮
                                    HStack {
                                        Menu {
                                            Picker("外观模式", selection: $selectedAppearance) {
                                                ForEach(AppAppearance.allCases) { mode in
                                                    HStack {
                                                        Image(systemName: mode.icon)
                                                        Text(mode.rawValue)
                                                    }
                                                    .tag(mode)
                                                }
                                            }
                                            .pickerStyle(.inline)
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.system(size: 24))
                                                .foregroundColor(.secondary.opacity(0.6))
                                                .contentShape(Rectangle())
                                        }
                                        .menuStyle(.borderlessButton)
                                        .menuIndicator(.hidden)
                                        .frame(width: 24, height: 28)
                                        .help("切换外观模式")
                                        
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 10)
                                    .zIndex(1)
                                    
                                    // 2. 标题
                                    Text("SaveTik_KZ")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .padding(.top, 40)
                                        .padding(.bottom, 20)
                                }
                
                // MARK: - Input Area
                HStack(spacing: 12) {
                    FixedTextField(
                        text: $urlInput,
                        placeholder: " 粘贴抖音视频分享链接... ",
                        onSubmit: handleFetchAction,
                        isFocused: $isInputFocused  // 🔥 传入焦点状态
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 10)
                    .background(AppTheme.cardColor(for: colorScheme))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.borderColor(for: colorScheme), lineWidth: 1)
                    )

                    // 获取/解析/清除 按钮
                    Button(action: handleFetchAction) {
                        HStack {
                            if isFetching {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                // 🔥 改用 shouldShowClearButton 判断
                                Image(systemName: shouldShowClearButton ? "xmark.circle.fill" : "link.circle.fill")
                            }
                            // 🔥 改用 shouldShowClearButton 判断
                            Text(isFetching ? "解析中" : (shouldShowClearButton ? "清除" : "获取"))
                        }
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 90, height: 42)
                        // 🔥 改用 shouldShowClearButton 判断背景色
                        .background((shouldShowClearButton || isFetching) ? Color.gray.opacity(0.2) : AppTheme.accentBlue)
                        .foregroundColor((shouldShowClearButton || isFetching) ? .primary : .white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFetching)
                }
                .padding(.horizontal, 60)
                
                // MARK: - Action Bar
                HStack {
                    if !videoList.isEmpty {
                        
                        // 1. 全选按钮
                        Button(action: selectAll) {
                            Text("全选")
                                .font(.system(size: 13))
                                .foregroundColor(isAllSelected ? .secondary.opacity(0.5) : .secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isAllSelected)
                        
                        // 2. 取消按钮
                        if isSelectionMode {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedVideos.removeAll()
                                }
                            }) {
                                Text("取消")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 12)
                            .transition(.opacity)
                            
                            Text("|")
                                .foregroundColor(.secondary.opacity(0.3))
                                .padding(.horizontal, 8)
                            
                            Text("已选 \(selectedVideos.count) 项")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        }
                        
                        Spacer()
                        
                        // 3. 下载按钮
                        if isSelectionMode {
                            Button(action: {
                                downloadSelected()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("下载选中")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.accentBlue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.top, 12)
                .frame(height: 44)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelectionMode)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAllSelected)
                .animation(.spring(), value: hasResults)
                .animation(.spring(), value: isFetching)
                
                // MARK: - Video List
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(videoList) { video in
                            VideoRow(
                                video: video,
                                isSelected: selectedVideos.contains(video.id),
                                isSelectionMode: isSelectionMode,
                                colorScheme: colorScheme,
                                onSelectToggle: {
                                    toggleSelection(for: video.id)
                                },
                                onDownloadSingle: {
                                    downloadSingle(video: video)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, 60)
                
                Spacer()
                
                // MARK: - Status Bar (完美居中 + 全栏点击)
                                HStack(spacing: 0) { // 外层 Stack：负责整体布局
                                    
                                    Spacer() // 🔥 左弹簧：把中间的内容推到正中央
                                    
                                    // 中间的内容组：紧凑排列
                                    HStack(spacing: 6) { // 图标和文字的间距设为 6，紧凑美观
                                        Image(systemName: statusIcon)
                                            .foregroundColor(statusColor)
                                        
                                        Text(statusMessage)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        
                                        // 箭头紧挨着文字
                                        Image(systemName: showLogPopover ? "chevron.down" : "chevron.up")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary.opacity(0.5))
                                            .frame(width: 12, height: 12)
                                            .padding(.leading, 2)
                                    }
                                    
                                    Spacer() //
                                    
                                }
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(Color.clear) 
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showLogPopover.toggle()
                                }
                                .popover(isPresented: $showLogPopover, arrowEdge: .bottom) {
                                    // --- 日志弹窗内容 (保持不变) ---
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack {
                                            Text("状态日志")
                                                .font(.headline)
                                            Spacer()
                                            Button("清除") {
                                                logs.removeAll()
                                                Task {
                                                    await checkBackendHealth()
                                                }
                                            }
                                            .font(.caption)
                                        }
                                        .padding()
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        
                                        List {
                                            ForEach(logs) { log in
                                                HStack(alignment: .top, spacing: 8) {
                                                    Image(systemName: log.type.icon)
                                                        .foregroundColor(log.type.color)
                                                        .font(.system(size: 12))
                                                        .padding(.top, 2)
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(log.message)
                                                            .font(.system(size: 13))
                                                            .foregroundColor(.primary)
                                                        Text(log.timeString)
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 2)
                                            }
                                        }
                                        .listStyle(.plain)
                                    }
                                    .frame(width: 450, height: 300)
                                }
                                .animation(.easeInOut(duration: 0.2), value: showLogPopover)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 10)
            }
        }
        .frame(minWidth: 700, minHeight: 550)
        .onAppear {
            applyAppearance(selectedAppearance)
        }
        .onChange(of: selectedAppearance) { _, newValue in
            applyAppearance(newValue)
        }
        .task {
            await checkBackendHealth()
            while true {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await checkBackendHealth()
            }
        }
    }
    
    // 🔥 强制修改 AppKit 底层外观，完美解决"跟随系统"失效问题
    func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .system:
            NSApp.appearance = nil // 设为 nil，App 就会立刻乖乖跟随系统设置
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua) // 强制浅色
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua) // 强制深色
        }
    }
    
    // MARK: - Logic Helpers
    func updateStatus(_ message: String, summary: String? = nil, type: LogType = .info) {
            // 1. 更新底部单行显示 (如果有 summary 就用 summary，没有就用原话)
            self.statusMessage = summary ?? message
            self.statusIcon = type.icon
            self.statusColor = type.color

            // 2. 追加到日志列表 (永远记录完整的 message)
            let newLog = LogEntry(message: message, type: type)
            self.logs.insert(newLog, at: 0)

            // 限制日志数量
            if self.logs.count > 50 {
                self.logs.removeLast()
            }
        }
    
    // 按钮点击处理
    func handleFetchAction() {
        if isFetching { return }
        
        // 🔥 修改逻辑：如果当前是“清除”模式（有结果或有报错）
        if shouldShowClearButton {
            urlInput = ""
            videoList = []
            selectedVideos = []
            currentMetadata = [:]
            hasError = false
            textFieldID = UUID()  // 🔥 重置 ID，强制重建 TextField
            updateStatus("准备就绪", type: .info)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isInputFocused = true
            }
        } else {
            // 获取逻辑
            if urlInput.isEmpty {
                if let clipboard = NSPasteboard.general.string(forType: .string) {
                    urlInput = clipboard
                }
            }
            startFetching()
        }
    }

    // 后端状态检测
        func checkBackendHealth() async {
            // 如果正在解析或下载中，暂停心跳检测，避免干扰
            if isFetching { return }
            
            let currentBaseURL = APIService.shared.baseURL
            // 如果 Python 还没把端口告诉 Swift，先别急
            if currentBaseURL.isEmpty { return }
            
            guard let url = URL(string: currentBaseURL) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            // ⚡️ 既然是本地且启动很快，超时设短一点，让 UI 反应更灵敏
            request.timeoutInterval = 1.0
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    // ✅ 成功连接 (后端已活)
                    await MainActor.run {
                        startupAttempts = 0 // 重置计数
                        
                        if !isBackendOnline {
                            isBackendOnline = true
                            // 🎉 这里改成 .success，直接变绿
                            updateStatus("服务已连接", summary: "准备就绪", type: .info)
                            
                            // 可选：如果是第一次连接成功，可以打印个日志爽一下
                            print("✅ 后端握手成功！")
                        }
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                // ❌ 连接失败 / 还没启动好
                await MainActor.run {
                    if isBackendOnline {
                        // 之前是好的，突然断了 -> 报错
                        isBackendOnline = false
                        updateStatus("连接中断", summary: "连接断开", type: .error)
                    } else {
                        // 🔥 启动阶段
                        startupAttempts += 1
                        
                        // 既然只要3秒，给10次机会(约10秒)足够了，给慢电脑留点余地
                        if startupAttempts <= 5 {
                            // ⚡️ 去掉倒计时数字，让界面更清爽
                            updateStatus("正在唤醒后端服务...", summary: "启动中...", type: .loading)
                        } else {
                            // 真的超时了
                            updateStatus("启动超时，请重启 App", summary: "启动失败", type: .error)
                        }
                    }
                }
            }
        }
    
    // 1. 解析逻辑
    func startFetching() {
            guard !urlInput.isEmpty else { return }
            
            isFetching = true
            updateStatus("正在获取...", type: .connect)
            
            videoList = []
            selectedVideos = []
            currentMetadata = [:]
            
            let rawText = urlInput
            print("发送给后端: \(rawText)")
            
            Task {
                do {
                    let (streams, meta) = try await APIService.shared.parse(url: rawText)
                    
                    await MainActor.run {
                        withAnimation(.spring()) {
                            self.videoList = streams
                            self.currentMetadata = meta ?? [:]
                            
                            updateStatus("解析完成: 获取到 \(streams.count) 个视频源", type: .success)
                        }
                        self.isFetching = false
                    }
                } catch {
                    await MainActor.run {
                        print("Swift 详细报错: \(error)")
                        let nsError = error as NSError
                        if nsError.domain == NSURLErrorDomain && nsError.code == -1011 {
                            updateStatus("链接无效，请输入正确的视频链接", type: .error)
                            self.hasError = true // 🔥 标记错误，触发“清除”按钮出现
                        } else {
                            updateStatus("出错: \(error.localizedDescription)", type: .error)
                            self.hasError = true // 🔥 网络错误通常也需要清除输入框
                        }
                        self.isFetching = false
                    }
                }
            }
        }
    
    // 2. 单个下载逻辑
        func downloadSingle(video: VideoStream, isBatchCall: Bool = false) {
            let index = (videoList.firstIndex(where: { $0.id == video.id }) ?? 0) + 1
            
            // 🔥 关键修复：如果不是批量调用（即用户点的单个下载），重置状态为“单任务模式”
            if !isBatchCall {
                batchTotal = 1
                batchSuccess = 0
                batchError = 0
                activeTasksCount = 0
            }
            
            activeTasksCount += 1 // 增加活跃任务
            
            // 单个下载时显示详细，批量时显示概览
            let loadingMsg = isBatchCall ? "准备下载中..." : "正在请求下载第 \(index) 个视频..."
            updateStatus("正在请求第 \(index) 个视频...", summary: loadingMsg, type: .loading)
            
            Task {
                do {
                    let taskId = try await APIService.shared.download(stream: video, metadata: self.currentMetadata)
                    await MainActor.run {
                        startPolling(taskId: taskId, videoIndex: index)
                    }
                } catch {
                    await MainActor.run {
                        activeTasksCount -= 1
                        batchError += 1
                        updateStatus("第 \(index) 个视频请求失败: \(error.localizedDescription)", type: .error)
                        // 立即结算
                        finalizeBatchIfNeeded()
                    }
                }
            }
        }
    
    // 3. 批量下载逻辑
    func downloadSelected() {
        let targets = videoList.filter { selectedVideos.contains($0.id) }
        guard !targets.isEmpty else { return }
        
        // 🔥 判断：如果只选了1个，按单个下载处理
        if targets.count == 1 {
            downloadSingle(video: targets[0], isBatchCall: false)
            return
        }
        
        // 🔥 下面是真正的批量下载（2个及以上）
        batchTotal = targets.count
        batchSuccess = 0
        batchError = 0
        activeTasksCount = 0
        
        updateStatus("开始批量下载 \(batchTotal) 个视频", summary: "准备批量下载...", type: .loading)
        
        for video in targets {
            downloadSingle(video: video, isBatchCall: true)
        }
    }
    
    // 4. 轮询逻辑 (使用 Swift 6 安全的 Task.sleep)
        func startPolling(taskId: String, videoIndex: Int) {
            Task {
                var isRunning = true
                while isRunning {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    do {
                        let status = try await APIService.shared.checkStatus(taskId: taskId)
                        await MainActor.run {
                            if status == "completed" {
                                batchSuccess += 1
                                activeTasksCount -= 1
                                isRunning = false
                                
                                // 🔥 分情况处理中间状态
                                if batchTotal == 1 {
                                    // 单个模式：直接显示成功
                                    updateStatus("第 \(videoIndex) 个视频下载成功", summary: "下载成功", type: .success)
                                } else {
                                    // 批量模式：只在日志里记一笔，不改底部 Summary（避免刷屏）
                                    updateStatus("第 \(videoIndex) 个视频下载成功", summary: nil, type: .success)
                                }
                                finalizeBatchIfNeeded()
                                
                            } else if status == "failed" {
                                batchError += 1
                                activeTasksCount -= 1
                                isRunning = false
                                
                                if batchTotal == 1 {
                                    // 单个模式：直接显示失败
                                    updateStatus("第 \(videoIndex) 个视频下载失败", summary: "下载失败", type: .error)
                                } else {
                                    // 批量模式：只记日志
                                    updateStatus("第 \(videoIndex) 个视频下载失败", summary: nil, type: .error)
                                }
                                finalizeBatchIfNeeded()
                                
                            } else {
                                // 🔄 只有批量模式才显示 "2/5" 这种进度，单个模式保持“下载中”
                                if batchTotal > 1 {
                                    let finished = batchSuccess + batchError
                                    self.statusMessage = "正在批量下载 (\(finished)/\(batchTotal))..."
                                } else {
                                    self.statusMessage = "正在下载视频..."
                                }
                                self.statusIcon = LogType.loading.icon
                                self.statusColor = LogType.loading.color
                            }
                        }
                    } catch { print("waiting...") }
                }
            }
        }
        
        // 🔥 新增：统一检查批次是否完成并汇总结果
        func finalizeBatchIfNeeded() {
            // 必须等所有任务跑完
            guard activeTasksCount == 0 else { return }
            
            // 🔥 如果是单个下载，前面已经报过结果了，这里直接返回，不再覆盖
            if batchTotal == 1 { return }
            
            // 🔥 下面是批量下载的总结逻辑
            if batchError > 0 {
                // 有失败项：红色警告
                updateStatus("批量任务结束：\(batchSuccess) 成功, \(batchError) 失败",
                             summary: "完成：\(batchSuccess) 成功，\(batchError) 失败",
                             type: .error)
            } else {
                // 全部成功：绿色
                updateStatus("所有视频下载成功",
                             summary: "全部 \(batchTotal) 个视频下载成功",
                             type: .success)
            }
        }
    
    // --- 选择辅助函数 ---
    func toggleSelection(for id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedVideos.contains(id) {
                selectedVideos.remove(id)
            } else {
                selectedVideos.insert(id)
            }
        }
    }
    
    func selectAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            let allIDs = videoList.map { $0.id }
            selectedVideos = Set(allIDs)
        }
    }
}

// MARK: - 4. 列表行组件
struct VideoRow: View {
    let video: VideoStream
    let isSelected: Bool
    let isSelectionMode: Bool
    let colorScheme: ColorScheme
    
    let onSelectToggle: () -> Void
    let onDownloadSingle: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. 图标
            ZStack {
                Image(systemName: "film")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(width: 44)
            
            // 2. 分辨率
            Text("\(video.width)x\(video.height)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            // 3. 分割线
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 14)
                .padding(.leading, 3)
                .padding(.trailing, 15)
            
            // 4.帧率
            Text("\(video.fps)FPS")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // 5. 编码
            Text(video.encoding)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            // 6. 码率
            Text("\(video.bitRate)b")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            // 7. HDR 标签
            if video.isHDR {
                Text("HDR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.yellow)
                    .cornerRadius(4)
                    .padding(.leading, 4)
            }
            
            Spacer()
            
            // 7. 操作按钮
            Button(action: {
                if isSelectionMode {
                    onSelectToggle()
                } else {
                    onDownloadSingle()
                }
            }) {
                ZStack {
                    if isSelectionMode {
                        if isSelected {
                            Image(systemName: "checkmark.app.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(AppTheme.accentBlue)
                                .transition(.scale)
                        } else {
                            Image(systemName: "app")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.secondary.opacity(0.5))
                                .transition(.opacity)
                        }
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(isHovering ? AppTheme.accentBlue : .secondary)
                            .transition(.scale)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
        }
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rowBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected ? AppTheme.accentBlue : AppTheme.borderColor(for: colorScheme),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        )
        .onTapGesture {
            onSelectToggle()
        }
        .onHover { isHovering = $0 }
    }
    
    var rowBackgroundColor: Color {
        if isSelected {
            return AppTheme.accentBlue.opacity(colorScheme == .dark ? 0.15 : 0.08)
        } else if isHovering {
            return AppTheme.hoverColor(for: colorScheme)
        } else {
            return AppTheme.cardColor(for: colorScheme)
        }
    }
}

#Preview {
    ContentView()
}
