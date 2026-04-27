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
    
    // 全局唯一的数据源 ViewModel
    @StateObject private var viewModel = ContentViewModel()
    
    // 纯 UI 的生命周期交互状态
    @State private var showFilterPopover: Bool = false
    @State private var showLogPopover: Bool = false
    
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
                // 边缘模糊过渡（保持不变）
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black, location: 0.05),
                            .init(color: .black, location: 0.95),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
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
        .onAppear { applyAppearance(selectedAppearance) }
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
