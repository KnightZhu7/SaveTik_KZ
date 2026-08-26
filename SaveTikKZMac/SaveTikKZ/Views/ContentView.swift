//
//  ContentView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/3/26.
//

import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @Environment(\.colorScheme) var systemColorScheme
    @AppStorage("appAppearance") private var selectedAppearance: AppAppearance = .system
    
    // 🔥 核心计算属性：启动与切换第 0 帧即可同步获取有效色彩模式，跟随系统时即刻无延迟联动真实系统环境
    private var effectiveColorScheme: ColorScheme {
        switch selectedAppearance {
        case .system:
            return AppAppearance.systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    @AppStorage("showSelectionMarquee") private var showSelectionMarquee: Bool = false
    
    // 全局唯一的数据源 ViewModel
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var scrollController = MarqueeScrollController()
    
    // 纯 UI 的生命周期交互状态
    @State private var showFilterPopover: Bool = false
    @State private var showLogPopover: Bool = false
    
    // 框选状态与坐标记录（统一基于全窗口坐标空间 AppWindowSpace 及文档空间）
    @State private var itemFramesInWindow: [UUID: CGRect] = [:]
    @State private var accumulatedItemDocFrames: [UUID: CGRect] = [:]
    @State private var resultsContainerFrameInWindow: CGRect = .zero
    @State private var dragStartWindowLocation: CGPoint? = nil
    @State private var startScrollOffset: CGFloat = 0
    @State private var visibleSelectionWindowRect: CGRect? = nil
    @State private var initialSelectionBeforeDrag: Set<UUID> = []
    @State private var currentMouseWindowLocation: CGPoint? = nil
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 背景层：加上颜色模式切换的平滑过渡
            AppTheme.backgroundColor(for: effectiveColorScheme)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.15), value: effectiveColorScheme)
            
            // 主体内容层：包含头部、搜索、列表、底部状态等
            VStack(spacing: 0) {
                // 1. 顶部 Header
                HeaderView()
                
                // 2. 搜索框区域
                SearchBarView(colorSchemeOverride: effectiveColorScheme, viewModel: viewModel)
                
                // 3. 操作栏 (全选、下载)
                ActionBarView(viewModel: viewModel)
                    .padding(.top, 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isSelectionMode)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isAllSelected)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.hasResults)
                
                // 4. 视频 / 图片 列表滚动区
                ZStack(alignment: .topLeading) {
                    ScrollView {
                        Group {
                            // 判断：如果图片列表里有数据，就渲染图片网格
                            if !viewModel.imageList.isEmpty {
                                ImageGridView(viewModel: viewModel, colorSchemeOverride: effectiveColorScheme)
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
                                                colorScheme: effectiveColorScheme,
                                                onSelectToggle: { viewModel.toggleSelection(for: video.id) },
                                                onDownloadSingle: { viewModel.downloadSingle(video: video) }
                                            )
                                            .transition(
                                                .asymmetric(
                                                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                                    removal: .opacity.combined(with: .scale(scale: 0.96))
                                                )
                                            )
                                        }
                                    }
                                }
                                .padding(.top, 5)
                                .padding(.vertical, 10)
                                .padding(.trailing, 16)
                                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: viewModel.displayedVideos)
                            }
                        }
                        .background(
                            ScrollViewAccessor { nsScrollView in
                                scrollController.attach(scrollView: nsScrollView)
                            }
                        )
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
                            Color.black
                                .frame(width: 16)
                        }
                    )
                    .padding(.leading, 60)
                    .padding(.trailing, 44)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ResultsContainerFrameKey.self,
                            value: proxy.frame(in: .named("AppWindowSpace"))
                        )
                    }
                )
                
                // 5. 底部状态与日志区
                StatusBarView(
                    viewModel: viewModel,
                    showLogPopover: $showLogPopover
                )
            }
            // 给整个主体 VStack 增加颜色模式切换的过渡动画
            .animation(.easeInOut(duration: 0.15), value: effectiveColorScheme)
            
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
        .coordinateSpace(name: "AppWindowSpace")
        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
            self.itemFramesInWindow = frames
            let currentScroll = scrollController.scrollOffset
            let containerTop = resultsContainerFrameInWindow.minY
            for (id, winFrame) in frames {
                let docFrame = CGRect(
                    x: winFrame.origin.x,
                    y: winFrame.origin.y - containerTop + currentScroll,
                    width: winFrame.width,
                    height: winFrame.height
                )
                accumulatedItemDocFrames[id] = docFrame
            }
        }
        .onPreferenceChange(ResultsContainerFrameKey.self) { frame in
            self.resultsContainerFrameInWindow = frame
        }
        .onChange(of: viewModel.displayedVideos) { _, _ in
            accumulatedItemDocFrames.removeAll()
        }
        .onChange(of: viewModel.displayedImages) { _, _ in
            accumulatedItemDocFrames.removeAll()
        }
        .onChange(of: viewModel.preferredGridColumns) { _, _ in
            accumulatedItemDocFrames.removeAll()
        }
        .overlay(
            GeometryReader { _ in
                // 🔥 框选高亮矩形：直接在 AppWindowSpace 全窗口绝对坐标绘制，0 像素偏移
                if viewModel.showSelectionMarquee, let rect = visibleSelectionWindowRect {
                    ZStack {
                        Path { path in
                            path.addRect(rect)
                        }
                        .fill(Color(nsColor: .controlAccentColor).opacity(0.14))
                        
                        Path { path in
                            path.addRect(rect)
                        }
                        .stroke(Color(nsColor: .controlAccentColor).opacity(0.85), lineWidth: 1)
                    }
                    // 🔥 核心遮罩：严格限制在结果列表容器内，外部（Header、SearchBar、ActionBar、StatusBar）绝不显示
                    .mask(
                        Group {
                            if resultsContainerFrameInWindow != .zero {
                                Path { path in
                                    path.addRect(resultsContainerFrameInWindow)
                                }
                            } else {
                                Color.black
                            }
                        }
                    )
                    .allowsHitTesting(false)
                }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("AppWindowSpace"))
                .onChanged { value in
                    guard viewModel.hasResults else { return }
                    
                    // 🔥 过滤：如果拖动起点在最顶部窗口拖动条区域（y < 20），不触发框选以保留窗口拖拽
                    if dragStartWindowLocation == nil && value.startLocation.y < 20 {
                        return
                    }
                    
                    let windowLoc = value.location
                    self.currentMouseWindowLocation = windowLoc
                    
                    let isImageMode = !viewModel.imageList.isEmpty
                    
                    if dragStartWindowLocation == nil {
                        let isCommandOrShift = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
                        if isImageMode {
                            initialSelectionBeforeDrag = isCommandOrShift ? viewModel.selectedImages : []
                        } else {
                            initialSelectionBeforeDrag = isCommandOrShift ? viewModel.selectedVideos : []
                        }
                        
                        dragStartWindowLocation = value.startLocation
                        startScrollOffset = scrollController.scrollOffset
                    }
                    
                    // 动态检测边缘自动滚动
                    let resultsTop = resultsContainerFrameInWindow.minY > 0 ? resultsContainerFrameInWindow.minY : 120
                    let resultsBottom = resultsContainerFrameInWindow.maxY > 0 ? resultsContainerFrameInWindow.maxY : (resultsTop + 400)
                    let edgeMargin: CGFloat = 36
                    
                    if windowLoc.y < resultsTop + edgeMargin {
                        // 靠近或超出列表顶部：向上滚动
                        let d = (resultsTop + edgeMargin) - windowLoc.y
                        let speed = -min(30.0, max(2.0, (d / edgeMargin) * 16.0))
                        scrollController.startAutoScroll(speed: speed) {
                            if let mouseLoc = self.currentMouseWindowLocation {
                                updateSelectionAndMarquee(currentWindowLocation: mouseLoc)
                            }
                        }
                    } else if windowLoc.y > resultsBottom - edgeMargin {
                        // 靠近或超出列表底部：向下滚动
                        let d = windowLoc.y - (resultsBottom - edgeMargin)
                        let speed = min(30.0, max(2.0, (d / edgeMargin) * 16.0))
                        scrollController.startAutoScroll(speed: speed) {
                            if let mouseLoc = self.currentMouseWindowLocation {
                                updateSelectionAndMarquee(currentWindowLocation: mouseLoc)
                            }
                        }
                    } else {
                        // 中间安全区：停止自动滚动
                        scrollController.stopAutoScroll()
                    }
                    
                    updateSelectionAndMarquee(currentWindowLocation: windowLoc)
                }
                .onEnded { _ in
                    scrollController.stopAutoScroll()
                    dragStartWindowLocation = nil
                    startScrollOffset = 0
                    visibleSelectionWindowRect = nil
                    initialSelectionBeforeDrag = []
                    currentMouseWindowLocation = nil
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
            let latestValue = UserDefaults.standard.object(forKey: "SaveTik_ShowMarquee") == nil ? true : UserDefaults.standard.bool(forKey: "SaveTik_ShowMarquee")
            if viewModel.showSelectionMarquee != latestValue {
                viewModel.showSelectionMarquee = latestValue
            }
        }
    }
    
    // MARK: - 框选与可视区域换算（文档空间与窗口空间协同计算）
    private func updateSelectionAndMarquee(currentWindowLocation: CGPoint) {
        guard let startLoc = dragStartWindowLocation else { return }
        
        let isImageMode = !viewModel.imageList.isEmpty
        let currentScrollOffset = scrollController.scrollOffset
        let containerTop = resultsContainerFrameInWindow.minY
        let deltaScroll = currentScrollOffset - startScrollOffset
        
        // 1. 视口空间高亮矩形（供屏幕上选框与 .mask 准确绘制）
        let anchorX = startLoc.x
        let anchorY = startLoc.y - deltaScroll
        
        let minWinX = min(anchorX, currentWindowLocation.x)
        let maxWinX = max(anchorX, currentWindowLocation.x)
        let minWinY = min(anchorY, currentWindowLocation.y)
        let maxWinY = max(anchorY, currentWindowLocation.y)
        
        let windowRect = CGRect(
            x: minWinX,
            y: minWinY,
            width: maxWinX - minWinX,
            height: maxWinY - minWinY
        )
        self.visibleSelectionWindowRect = windowRect
        
        // 2. 文档空间选区矩形（解决滚出可视区后的元素不被意外取消选择）
        let startDocY = startLoc.y - containerTop + startScrollOffset
        let currDocY = currentWindowLocation.y - containerTop + currentScrollOffset
        
        let minDocX = minWinX
        let maxDocX = maxWinX
        let minDocY = min(startDocY, currDocY)
        let maxDocY = max(startDocY, currDocY)
        
        let docRect = CGRect(
            x: minDocX,
            y: minDocY,
            width: maxDocX - minDocX,
            height: maxDocY - minDocY
        )
        
        // 3. 将当前帧最新可见列表项的 docFrame 实时登记入库
        for (id, winFrame) in itemFramesInWindow {
            let docFrame = CGRect(
                x: winFrame.origin.x,
                y: winFrame.origin.y - containerTop + currentScrollOffset,
                width: winFrame.width,
                height: winFrame.height
            )
            accumulatedItemDocFrames[id] = docFrame
        }
        
        // 4. 在全量文档空间中计算相交（滚出屏幕外的已选元素依然稳固保持在集合内）
        var newlyIntersected = Set<UUID>()
        for (id, docFrame) in accumulatedItemDocFrames {
            if docRect.intersects(docFrame) {
                newlyIntersected.insert(id)
            }
        }
        
        withAnimation(.easeInOut(duration: 0.08)) {
            if isImageMode {
                viewModel.selectedImages = initialSelectionBeforeDrag.union(newlyIntersected)
            } else {
                viewModel.selectedVideos = initialSelectionBeforeDrag.union(newlyIntersected)
            }
        }
    }
    
    // 修改系统外观
    private func applyAppearance(_ appearance: AppAppearance) {
        AppAppearance.apply(appearance)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
