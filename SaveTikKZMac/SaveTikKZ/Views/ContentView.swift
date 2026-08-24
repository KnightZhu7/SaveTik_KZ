//
//  ContentView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/3/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appAppearance") private var selectedAppearance: AppAppearance = .system
    
    @AppStorage("showSelectionMarquee") private var showSelectionMarquee: Bool = false
    
    // 全局唯一的数据源 ViewModel
    @StateObject private var viewModel = ContentViewModel()
    
    // 纯 UI 的生命周期交互状态
    @State private var showFilterPopover: Bool = false
    @State private var showLogPopover: Bool = false
    
    // 🔥【新增 1】：框选状态与坐标记录
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil
    @State private var initialSelectionBeforeDrag: Set<UUID> = []
    
    // 🔥【新增 2】：动态计算框选矩形
    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(start.x - current.x),
            height: abs(start.y - current.y)
        )
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 背景层：加上颜色模式切换的平滑过渡
            AppTheme.backgroundColor(for: colorScheme)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.1), value: colorScheme)
//                .animation(.easeInOut(duration: 0.4), value: selectedAppearance)
            
            // 主体内容层：包含头部、搜索、列表、底部状态等
            VStack(spacing: 0) {
                // 1. 顶部 Header
                HeaderView()
                
                // 2. 搜索框区域
                SearchBarView(viewModel: viewModel)
                
                // 3. 操作栏 (全选、下载)
                ActionBarView(viewModel: viewModel)
                    .padding(.top, 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isSelectionMode)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isAllSelected)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.hasResults)
                
                // 4. 视频 / 图片 列表滚动区
                ScrollView {
                    // 🔥 判断：如果图片列表里有数据，就渲染我们刚写的图片网格
                    if !viewModel.imageList.isEmpty {
                        ImageGridView(viewModel: viewModel)
                            .transition(.opacity)
                    }
                    // 否则走原来的视频列表逻辑
                    else {
                        VStack(spacing: 8) {
                            if viewModel.displayedVideos.isEmpty && !viewModel.videoList.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("当前筛选条件下无匹配视频")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary.opacity(0.7))
                                    Spacer()
                                }
                                .frame(height: 50)
                                .transition(.opacity)
                                
                            } else {
                                ForEach(viewModel.displayedVideos) { video in
                                    VideoRow(
                                        video: video,
                                        isSelected: viewModel.selectedVideos.contains(video.id),
                                        isSelectionMode: viewModel.isSelectionMode,
                                        colorScheme: colorScheme,
                                        onSelectToggle: { viewModel.toggleSelection(for: video.id) },
                                        onDownloadSingle: { viewModel.downloadSingle(video: video) }
                                    )
                                    .transition(.opacity)
                                }
                            }
                        }
                        .padding(.top, 5)
                        .padding(.vertical, 10)
                        .padding(.trailing, 16)
                    }
                }
                // 边缘模糊过渡（固定像素控制）
                .mask(
                    HStack(spacing: 0) {
                        // 左侧：列表主体内容区域，上下固定像素模糊
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: 15)
                            
                            // 中间全量显示区域
                            Color.black
                            
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 15)
                        }
                        
                        // 右侧：预留给滚动条的区域（macOS 滚动条大约占 16px）
                        // 使用纯黑遮罩，确保滚动条本身不会在顶部和底部被透明度渐渐隐藏
                        Color.black
                            .frame(width: 16)
                    }
                )
                .padding(.leading, 60)
                .padding(.trailing, 44)
                
                // 5. 底部状态与日志区
                StatusBarView(
                    viewModel: viewModel,
                    showLogPopover: $showLogPopover
                )
            }
            // 给整个主体 VStack 增加颜色模式切换的过渡动画
            .animation(.easeInOut(duration: 0.1), value: colorScheme)
            
            // 悬浮层：单独的按钮组，不受上述颜色切换动画的影响
            HeaderButtonGroup(
                viewModel: viewModel,
                selectedAppearance: $selectedAppearance,
                showFilterPopover: $showFilterPopover
            )
            .padding(.trailing, 10)
            .padding(.top, 8)
            .ignoresSafeArea(.container, edges: .top)

        }
        .frame(minWidth: 700, minHeight: 550)
        // 🔥【新增开始】：统一使用全窗口坐标空间
        .coordinateSpace(name: "AppWindowSpace")
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            self.itemFrames = frames
        }
        .overlay(
            GeometryReader { _ in
                // 🔥 读取 viewModel.showSelectionMarquee
                if viewModel.showSelectionMarquee, let rect = selectionRect {
                    Path { path in
                        path.addRect(rect)
                    }
                    .fill(Color(nsColor: .controlAccentColor).opacity(0.14))
                    .overlay(
                        Path { path in
                            path.addRect(rect)
                        }
                        .stroke(Color(nsColor: .controlAccentColor).opacity(0.85), lineWidth: 1)
                    )
                    .allowsHitTesting(false)
                }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("AppWindowSpace"))
                .onChanged { value in
                    guard viewModel.hasResults else { return }
                    
                    // 🔥【核心过滤】：如果拖动起点在顶部 48pt 内（窗口拖拽/Header 区域），不触发框选
                    if dragStart == nil && value.startLocation.y < 50 {
                        return
                    }
                    
                    let isImageMode = !viewModel.imageList.isEmpty
                    
                    if dragStart == nil {
                        dragStart = value.startLocation
                        let isCommandOrShift = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
                        
                        if isImageMode {
                            initialSelectionBeforeDrag = isCommandOrShift ? viewModel.selectedImages : []
                        } else {
                            initialSelectionBeforeDrag = isCommandOrShift ? viewModel.selectedVideos : []
                        }
                    }
                    
                    dragCurrent = value.location
                    
                    guard let rect = selectionRect else { return }
                    
                    var newlyIntersected = Set<UUID>()
                    for (id, itemFrame) in itemFrames {
                        if rect.intersects(itemFrame) {
                            newlyIntersected.insert(id)
                        }
                    }
                    
                    withAnimation(.easeInOut(duration: 0.1)) {
                        if isImageMode {
                            viewModel.selectedImages = initialSelectionBeforeDrag.union(newlyIntersected)
                        } else {
                            viewModel.selectedVideos = initialSelectionBeforeDrag.union(newlyIntersected)
                        }
                    }
                }
                .onEnded { _ in
                    dragStart = nil
                    dragCurrent = nil
                    initialSelectionBeforeDrag = []
                }
        )
        .onAppear {
            applyAppearance(selectedAppearance)
            // 阻止 macOS 默认将焦点交给首个 NSTextField
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .onChange(of: selectedAppearance) { _, newValue in applyAppearance(newValue) }
        .task {
            await viewModel.checkBackendHealth()
            while true {
                // 已连接后放宽到 10 秒，减少 70% 的空闲请求量
                let interval: UInt64 = viewModel.isBackendOnline
                    ? 10_000_000_000   // 10 秒
                    : 3_000_000_000    // 3 秒（启动阶段快速探测）
                try? await Task.sleep(nanoseconds: interval)
                await viewModel.checkBackendHealth()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            let latestValue = UserDefaults.standard.bool(forKey: "SaveTik_ShowMarquee")
            if viewModel.showSelectionMarquee != latestValue {
                viewModel.showSelectionMarquee = latestValue
            }
        }
    }
    
    // 修改系统外观
    private func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

#Preview {
    ContentView()
}
