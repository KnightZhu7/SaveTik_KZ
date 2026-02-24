//
//  ContentView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/3/26.
//

import SwiftUI
import UniformTypeIdentifiers

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

// 🔥 拦截原生获焦行为的自定义输入框
class NonSelectingTextField: NSTextField {
    private var hasAutoFocusedOnLaunch = false
    
    // 1. 解决刚启动时没焦点：监听窗口挂载事件，挂载成功后立刻抢占焦点
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if !hasAutoFocusedOnLaunch, self.window != nil {
            hasAutoFocusedOnLaunch = true
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }
    }
    
    // 2. 解决闪烁和全选：直接在当前帧抹除全选状态
    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        if success, let editor = self.currentEditor() as? NSTextView {
            let length = self.stringValue.count
            editor.selectedRange = NSRange(location: length, length: 0)
        }
        return success
    }
}

// NSViewRepresentable 包装原生 NSTextField
struct FixedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    @Binding var requestFocus: Bool  // 🔥 弃用 @FocusState，改用普通 Binding 触发器
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NonSelectingTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 13)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        
        if let cell = textField.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.wraps = false
            cell.isScrollable = true
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // 🔥 单向触发：只要收到 true 请求，就强制聚焦，然后重置
        if requestFocus {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder != nsView.currentEditor() {
                    nsView.window?.makeFirstResponder(nsView)
                }
                self.requestFocus = false // 消费掉请求，以备下次触发
            }
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
        // ⚠️ 注意：Coordinator 里不要写监听焦点失去/获得的代码，切断 AppKit 反向干扰 SwiftUI
    }
}

// MARK: - 3. 主视图
struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appAppearance") private var selectedAppearance: AppAppearance = .system
    
    @Namespace private var animationNamespace
    
    // --- 核心数据状态 ---
    @State private var urlInput: String = ""
    @State private var isFetching: Bool = false
    @State private var videoList: [VideoStream] = []
    @State private var selectedVideos: Set<UUID> = []
    
    // --- 筛选与排序状态 ---
    @State private var showFilterPopover: Bool = false
    @State private var showOnlyHighestBitrate: Bool = false
    @State private var primarySort: SortPriority = .resolution
    
    @State private var resolutionTokens: [FilterToken] = []
    @State private var encodingTokens: [FilterToken] = []
    
    // 拖拽跟踪变量
    @State private var draggedResToken: FilterToken?
    @State private var draggedEncToken: FilterToken?
     @State private var dragOffset: CGSize = .zero
     @State private var draggingID: UUID? = nil
    
    // 🔥 核心逻辑：替换原本所有使用 videoList 的地方
    var displayedVideos: [VideoStream] {
        // 1. 过滤：分辨率和编码的亮灭状态
        var result = videoList.filter { video in
            let resName = "\(min(video.width, video.height))P"
            let isResOn = resolutionTokens.first(where: { $0.name == resName })?.isOn ?? false
            let isEncOn = encodingTokens.first(where: { $0.name == video.encoding })?.isOn ?? false
            return isResOn && isEncOn
        }
        
        // 2. 过滤：仅保留最高码率
        if showOnlyHighestBitrate {
            var grouped: [String: VideoStream] = [:]
            for video in result {
                let key = "\(min(video.width, video.height))P_\(video.encoding)_\(video.isHDR ? "hdr" : "sdr")"
                if let existing = grouped[key] {
                    if video.bitRate > existing.bitRate { grouped[key] = video }
                } else {
                    grouped[key] = video
                }
            }
            result = Array(grouped.values)
        }
        
        // 3. 🔥 完美三级排序：首级优先级 -> 次级优先级 -> 码率大到小
        result.sort { v1, v2 in
            let resName1 = "\(min(v1.width, v1.height))P"
            let resName2 = "\(min(v2.width, v2.height))P"
            
            let resIndex1 = resolutionTokens.firstIndex(where: { $0.name == resName1 }) ?? 99
            let resIndex2 = resolutionTokens.firstIndex(where: { $0.name == resName2 }) ?? 99
            let encIndex1 = encodingTokens.firstIndex(where: { $0.name == v1.encoding }) ?? 99
            let encIndex2 = encodingTokens.firstIndex(where: { $0.name == v2.encoding }) ?? 99
            
            if primarySort == .resolution {
                if resIndex1 != resIndex2 { return resIndex1 < resIndex2 } // 1. 分辨率
                if encIndex1 != encIndex2 { return encIndex1 < encIndex2 } // 2. 编码
            } else {
                if encIndex1 != encIndex2 { return encIndex1 < encIndex2 } // 1. 编码
                if resIndex1 != resIndex2 { return resIndex1 < resIndex2 } // 2. 分辨率
            }
            
            // 3. 兜底次级优先级：码率从大到小
            return v1.bitRate > v2.bitRate
        }
        return result
    }
    
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
//    @FocusState private var isInputFocused: Bool
    @State private var requestFocus: Bool = false
    @State private var textFieldID = UUID()
    // --- 批量下载追踪 ---
    @State private var activeTasksCount: Int = 0      // 正在进行的任务数
    @State private var batchTotal = 0        // 本次选中的总数
    @State private var batchSuccess = 0      // 已成功的数量
    @State private var batchError = 0        // 已失败的数量
    
    // --- 计算属性 ---
    var isSelectionMode: Bool {
        !selectedVideos.isEmpty
    }
    
    var isAllSelected: Bool {
        !displayedVideos.isEmpty && selectedVideos.count == displayedVideos.count
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
                                            // 🔥 直接对图标“点石成金”
                                            Image(systemName: "ellipsis.circle.fill")
                                                .font(.system(size: 18))
                                                // 1. 开启分层渲染模式
                                                .symbolRenderingMode(.palette)
                                                // 2. 第一个参数管“三个点”的颜色，第二个参数直接把“液态玻璃”灌进“圆圈”里！
                                                .foregroundStyle(Color.primary.opacity(0.6), .regularMaterial)
                                                // 3. 加一点点立体阴影
                                                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                        }
                                        .menuIndicator(.hidden)
                                        // 扒掉系统默认的灰色方块按钮底板，只展示我们漂亮的图标
                                        .buttonStyle(.plain)
                                        .help("切换外观模式")
                                        if hasResults {
                                            Button(action: { showFilterPopover.toggle() }) {
                                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                                    .font(.system(size: 18))
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(Color.primary.opacity(0.6), .regularMaterial)
                                                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                                                    // 🔥 1. 明确图标的响应大小，让箭头准确找到中心
                                                    .frame(width: 24, height: 24)
                                            }
                                            .buttonStyle(.plain)
                                            // 🔥 2. popover 必须紧贴 Button 绑定，放在 padding 前面
                                            .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                                                filterPopoverView
                                            }
                                            .padding(.leading, 8) // padding 移到这里
                                            .transition(.opacity.combined(with: .scale))
                                        }
                                        Spacer()
                                    }
                                    .frame(height: 24)
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
                        requestFocus: $requestFocus
                    )
                    .id(textFieldID)
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
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasResults)
                .animation(.spring(), value: hasResults)
                .animation(.spring(), value: isFetching)
                // 在 Action Bar 的最后一个 .animation 修饰符后添加
                .onChange(of: resolutionTokens) { _, _ in
                    // 🔥 放入主队列异步执行，让原生组件自身的动画先安全闭环
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedVideos.removeAll()
                        }
                    }
                }
                .onChange(of: encodingTokens) { _, _ in
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedVideos.removeAll()
                        }
                    }
                }
                .onChange(of: showOnlyHighestBitrate) { _, _ in
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedVideos.removeAll()
                        }
                    }
                }
                .onChange(of: primarySort) { _, _ in
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedVideos.removeAll()
                        }
                    }
                }
                
                // MARK: - Video List
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(displayedVideos) { video in
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
                                    // --- 🔥 风格统一的日志弹窗内容 ---
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Text("状态日志")
                                                .font(.headline)
                                            Spacer()
                                            Button(action: {
                                                logs.removeAll()
                                                Task { await checkBackendHealth() }
                                            }) {
                                                Text("清除日志")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 4)
                                                    .background(Color.secondary.opacity(0.15))
                                                    .cornerRadius(6)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        Divider()
                                        
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 12) {
                                                if logs.isEmpty {
                                                    Text("暂无日志记录")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(.secondary)
                                                        .frame(maxWidth: .infinity, alignment: .center)
                                                        .padding(.top, 20)
                                                } else {
                                                    ForEach(logs) { log in
                                                        HStack(alignment: .top, spacing: 10) {
                                                            Image(systemName: log.type.icon)
                                                                .foregroundColor(log.type.color)
                                                                .font(.system(size: 12))
                                                                .padding(.top, 2)
                                                            
                                                            VStack(alignment: .leading, spacing: 4) {
                                                                Text(log.message)
                                                                    .font(.system(size: 13))
                                                                    .foregroundColor(.primary)
                                                                Text(log.timeString)
                                                                    .font(.system(size: 11))
                                                                    .foregroundColor(.secondary.opacity(0.8))
                                                            }
                                                            Spacer()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(20)
                                    .frame(width: 380, height: 300) // 🔥 宽度改为 380，与上方筛选器保持一致
                                }
                                .animation(.easeInOut(duration: 0.2), value: showLogPopover)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 10)
            }
//            if let firstVideo = videoList.first {
//                VStack {
//                    Spacer() // 把内容推到底部
//                    HStack {
//                        Spacer() // 把内容推到右侧
//
//                        let isVertical = firstVideo.width < firstVideo.height
//
//                        // 仅保留横竖屏标签
//                        Text(isVertical ? "竖屏" : "横屏")
//                            .font(.system(size: 11, weight: .bold))
//                            .foregroundColor(isVertical ? AppTheme.accentBlue : .secondary)
//                            // 稍微增加一点内边距，让单身标签显得更饱满
//                            .padding(.horizontal, 10)
//                            .padding(.vertical, 5)
//                            .background(AppTheme.cardColor(for: colorScheme)) // 防文字穿透底色
//                            .background((isVertical ? AppTheme.accentBlue : Color.secondary).opacity(0.15)) // 叠加色
//                            .cornerRadius(6)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 6)
//                                    .strokeBorder(isVertical ? AppTheme.accentBlue.opacity(0.3) : AppTheme.borderColor(for: colorScheme), lineWidth: 1)
//                            )
//                            // 增加极其微弱的阴影，让孤立的标签更有悬浮感
//                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
//                            // 🔥 核心对齐：列表距右边是 60，这里设为 75，刚好往左缩一点，留出距离
//                            .padding(.trailing, 75)
//                            .padding(.bottom, 50) // 悬浮在底部状态栏上方
//                            .transition(.opacity.combined(with: .move(edge: .bottom)))
//                    }
//                }
//                .zIndex(2) // 强制漂浮在列表上方
//            }
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                urlInput = ""
                videoList = []
                selectedVideos = []
                currentMetadata = [:]
                hasError = false
            }
            textFieldID = UUID()  // 🔥 重置 ID，强制重建 TextField
            updateStatus("准备就绪", type: .info)
            requestFocus = true
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
                            
                            // 🔥 初始化筛选标签 (默认按从大到小原生排序)
                            let uniqueRes = Array(Set(streams.map { "\(min($0.width, $0.height))P" }))
                                .sorted { (Int($0.dropLast()) ?? 0) > (Int($1.dropLast()) ?? 0) }
                            self.resolutionTokens = uniqueRes.map { FilterToken(name: $0, isOn: true) }
                            
                            let uniqueEnc = Array(Set(streams.map { $0.encoding })).sorted()
                            self.encodingTokens = uniqueEnc.map { FilterToken(name: $0, isOn: true) }
                            // -------------------------
                            
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
            let index = (displayedVideos.firstIndex(where: { $0.id == video.id }) ?? 0) + 1
            
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
    
    // 4. 轮询逻辑
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
                            
                            if batchTotal == 1 {
                                // 单个模式：更新状态栏
                                updateStatus("第 \(videoIndex) 个视频下载成功", summary: "下载成功", type: .success)
                            } else {
                                // 🔥 批量模式：只写日志，不更新状态栏
                                let log = LogEntry(message: "第 \(videoIndex) 个视频下载成功", type: .success)
                                logs.insert(log, at: 0)
                                if logs.count > 50 {
                                    logs.removeLast()
                                }
                            }
                            finalizeBatchIfNeeded()
                            
                        } else if status == "failed" {
                            batchError += 1
                            activeTasksCount -= 1
                            isRunning = false
                            
                            if batchTotal == 1 {
                                // 单个模式：更新状态栏
                                updateStatus("第 \(videoIndex) 个视频下载失败", summary: "下载失败", type: .error)
                            } else {
                                // 🔥 批量模式：只写日志，不更新状态栏
                                let log = LogEntry(message: "第 \(videoIndex) 个视频下载失败", type: .error)
                                logs.insert(log, at: 0)
                                if logs.count > 50 {
                                    logs.removeLast()
                                }
                            }
                            finalizeBatchIfNeeded()
                            
                        } else {
                            // 🔄 进行中状态：更新状态栏
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
            let allIDs = displayedVideos.map { $0.id }
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
            Text("\(min(video.width, video.height))P")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 60, alignment: .leading)
//            HStack(spacing: 6) {
//                // 取宽高中较小的值，并加上 "P" (例如 1080P)
//                Text("\(min(video.width, video.height))P")
//                    .font(.system(size: 13, weight: .bold, design: .monospaced))
//                    .foregroundColor(.primary)
//
//                // 对比宽高判断横竖屏，并做成一个精致的小标签
//                Text(video.width < video.height ? "竖屏" : "横屏")
//                    .font(.system(size: 10, weight: .medium))
//                    .foregroundColor(video.width < video.height ? AppTheme.accentBlue : .secondary)
//                    .padding(.horizontal, 4)
//                    .padding(.vertical, 2)
//                    .background(
//                        (video.width < video.height ? AppTheme.accentBlue : Color.secondary).opacity(0.15)
//                    )
//                    .cornerRadius(4)
//            }
//            .frame(width: 100, alignment: .leading)
            
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

// MARK: - 5. 筛选面板扩展与模型
enum SortPriority: String, CaseIterable, Identifiable {
    case resolution = "分辨率优先"
    case encoding = "编码优先"
    var id: String { self.rawValue }
}

struct FilterToken: Identifiable, Equatable {
    let id = UUID()
    let name: String
    var isOn: Bool
    
    // 用于内部排序的数值大小（例如 1080P -> 1080）
    var numericValue: Int {
        Int(name.filter { $0.isNumber }) ?? 0
    }
}

// 🔥 原生拖拽重新排序代理
struct TokenDropDelegate: DropDelegate {
    let item: FilterToken
    @Binding var items: [FilterToken]
    @Binding var draggedItem: FilterToken?
    var onDropEnded: () -> Void // 🔥 新增：通过回调在父视图安全执行延迟

    func dropEntered(info: DropInfo) {
        guard let draggedItem = self.draggedItem else { return }
        // 只允许在亮着的标签之间拖动
        guard item.isOn && draggedItem.isOn else { return }
        guard draggedItem != item else { return }

        if let from = items.firstIndex(of: draggedItem), let to = items.firstIndex(of: item) {
            withAnimation(.default) {
                self.items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        // 🔥 执行回调，将延迟任务交回主视图
        onDropEnded()
        return true
    }
}

extension ContentView {

    func toggleToken(_ token: FilterToken, isRes: Bool) {
        self.draggedResToken = nil
        self.draggedEncToken = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            var array = isRes ? resolutionTokens : encodingTokens
            guard let index = array.firstIndex(where: { $0.id == token.id }) else { return }
            if array[index].isOn && array.filter({ $0.isOn }).count == 1 { return }
            array[index].isOn.toggle()
            let onTokens  = array.filter { $0.isOn }
            let offTokens = array.filter { !$0.isOn }.sorted {
                isRes ? ($0.numericValue > $1.numericValue) : ($0.name < $1.name)
            }
            if isRes { resolutionTokens = onTokens + offTokens }
            else     { encodingTokens  = onTokens + offTokens }
        }
    }

    // MARK: 可拖拽标签行（横向）
    @ViewBuilder
    func draggableTokenRow(
        tokens: Binding<[FilterToken]>,
        draggedToken: Binding<FilterToken?>,
        isRes: Bool
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tokens.wrappedValue) { token in
                        TokenChip(
                            token: token,
                            isDragging: draggedToken.wrappedValue?.id == token.id,
                            onTap: { toggleToken(token, isRes: isRes) }
                        )
                        .id(token.id)
                        // ── 拖拽手势 ──────────────────────────────────────
                        .gesture(
                            token.isOn ?
                            DragGesture(minimumDistance: 4, coordinateSpace: .named("hstack_\(isRes)"))
                                .onChanged { value in
                                    // 1. 标记当前正在拖的 token
                                    if draggedToken.wrappedValue?.id != token.id {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                            draggedToken.wrappedValue = token
                                        }
                                    }

                                    // 2. 根据拖拽 X 位置重新排序
                                    reorderTokens(
                                        tokens: tokens,
                                        dragged: token,
                                        xLocation: value.location.x
                                    )

                                    // 3. 靠近左/右边界时自动滚动
                                    let edgeThreshold: CGFloat = 50
                                    if value.location.x < edgeThreshold {
                                        // 往左找前一个
                                        if let idx = tokens.wrappedValue.firstIndex(where: { $0.id == token.id }),
                                           idx > 0 {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                proxy.scrollTo(tokens.wrappedValue[idx - 1].id, anchor: .leading)
                                            }
                                        }
                                    } else if value.location.x > scrollTriggerRight(isRes: isRes) {
                                        if let idx = tokens.wrappedValue.firstIndex(where: { $0.id == token.id }),
                                           idx < tokens.wrappedValue.count - 1 {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                proxy.scrollTo(tokens.wrappedValue[idx + 1].id, anchor: .trailing)
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    // 无论在哪里松手，都清理状态
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        draggedToken.wrappedValue = nil
                                    }
                                }
                            : nil
                        )
                    }
                }
                .padding(.vertical, 2)
                .coordinateSpace(name: "hstack_\(isRes)")
            }
        }
    }

    /// 根据拖拽的 X 坐标，判断应该插入到哪个位置并执行移动
    private func reorderTokens(
        tokens: Binding<[FilterToken]>,
        dragged: FilterToken,
        xLocation: CGFloat
    ) {
        var arr = tokens.wrappedValue
        guard let fromIdx = arr.firstIndex(where: { $0.id == dragged.id }) else { return }

        // 粗估：每个 chip 约 60pt（含间距），用坐标除以它来得到目标 index
        let chipWidth: CGFloat = 64
        let toIdx = max(0, min(arr.count - 1, Int(xLocation / chipWidth)))

        // 只在 isOn 的范围内移动
        guard arr[toIdx].isOn else { return }
        guard toIdx != fromIdx else { return }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            arr.move(
                fromOffsets: IndexSet(integer: fromIdx),
                toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
            )
            tokens.wrappedValue = arr
        }
    }

    /// 滚动触发的右侧边界（基于面板宽度减去左侧标签宽度）
    private func scrollTriggerRight(isRes: Bool) -> CGFloat {
        // 面板总宽 380，左侧标签约 83pt（"分辨率:" + padding）
        return 380 - 83 - 50
    }

    // MARK: - 筛选弹窗 UI
    @ViewBuilder
    var filterPopoverView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("高级筛选与排序").font(.headline)
                Spacer()
                Toggle("仅最高码率", isOn: $showOnlyHighestBitrate.animation(.spring(response: 0.3, dampingFraction: 0.7)))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            Divider()

            // 优先级切换
            HStack {
                Text("优先级:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 75, alignment: .leading)

                HStack(spacing: 0) {
                    ForEach(SortPriority.allCases) { priority in
                        Text(priority.rawValue)
                            .font(.system(size: 12, weight: primarySort == priority ? .bold : .medium))
                            .foregroundColor(primarySort == priority ? .white : .primary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                ZStack {
                                    if primarySort == priority {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(AppTheme.accentBlue)
                                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                            .matchedGeometryEffect(id: "SEGMENT", in: animationNamespace)
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    primarySort = priority
                                }
                            }
                    }
                }
                .padding(2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .frame(width: 180)
            }

            // 分辨率行
            HStack(spacing: 8) {
                Text("分辨率:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 75, alignment: .leading)

                draggableTokenRow(
                    tokens: $resolutionTokens,
                    draggedToken: $draggedResToken,
                    isRes: true
                )
            }

            // 编码行
            HStack(spacing: 8) {
                Text("编    码:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 75, alignment: .leading)

                draggableTokenRow(
                    tokens: $encodingTokens,
                    draggedToken: $draggedEncToken,
                    isRes: false
                )
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

// MARK: - Token 标签子视图（独立出来方便复用）
private struct TokenChip: View {
    let token: FilterToken
    let isDragging: Bool
    let onTap: () -> Void

    var body: some View {
        Text(token.name)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(token.isOn ? AppTheme.accentBlue : Color.gray.opacity(0.2))
            .foregroundColor(token.isOn ? .white : .primary.opacity(0.4))
            .cornerRadius(6)
            // 拖拽中：放大 + 轻微上浮阴影，松手后还原
            .scaleEffect(isDragging ? 1.08 : 1.0)
            .shadow(
                color: isDragging ? .black.opacity(0.18) : .clear,
                radius: isDragging ? 6 : 0,
                x: 0, y: isDragging ? 3 : 0
            )
            .opacity(isDragging ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
            .onTapGesture { onTap() }
    }
}

