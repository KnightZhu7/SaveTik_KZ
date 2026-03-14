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
    
    // 🔥 requestFocus 和 textFieldID 已经被彻底删除了
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor(for: colorScheme).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. 顶部 Header
                HeaderView(
                    viewModel: viewModel,
                    selectedAppearance: $selectedAppearance,
                    showFilterPopover: $showFilterPopover
                )
                
                // 2. 搜索框区域 (🔥 调用变得极简)
                SearchBarView(viewModel: viewModel)
                
                // 3. 操作栏 (全选、下载)
                ActionBarView(viewModel: viewModel)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isSelectionMode)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isAllSelected)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.hasResults)
                
                // 4. 视频列表滚动区
                ScrollView {
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
                            .transition(.opacity) // 纯粹的淡入淡出
                            
                        } else {
                            // 正常的视频列表
                            ForEach(viewModel.displayedVideos) { video in
                                VideoRow(
                                    video: video,
                                    isSelected: viewModel.selectedVideos.contains(video.id),
                                    isSelectionMode: viewModel.isSelectionMode,
                                    colorScheme: colorScheme,
                                    onSelectToggle: { viewModel.toggleSelection(for: video.id) },
                                    onDownloadSingle: { viewModel.downloadSingle(video: video) }
                                )
                                .transition(.opacity) // 正常的淡出
                            }
                        }
                    }
                    .padding(.vertical, 10)
                }
                .padding(.horizontal, 60)
                
                // 5. 底部状态与日志区
                StatusBarView(
                    viewModel: viewModel,
                    showLogPopover: $showLogPopover
                )
            }
        }
        .frame(minWidth: 700, minHeight: 550)
        .onAppear { applyAppearance(selectedAppearance) }
        .onChange(of: selectedAppearance) { _, newValue in applyAppearance(newValue) }
        .task {
            await viewModel.checkBackendHealth()
            while true {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
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
