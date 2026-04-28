//
//  ActionBarView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI
import AppKit

struct ActionBarView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    // 追踪底层系统事件状态
    @State private var isOptionPressed: Bool = false
    @State private var isHoveringDownloadBtn: Bool = false
    @State private var flagsMonitor: Any?
    
    // 触发隐藏菜单的终极条件：满足选图规则 + 按住 Option + 鼠标指向按钮
    private var isSynthesisMode: Bool {
        viewModel.canSynthesizeLivePhoto && isOptionPressed && isHoveringDownloadBtn
    }
    
    var body: some View {
        HStack {
            if viewModel.hasResults {
                Button(action: {
                    viewModel.selectAll()
                }) {
                    Text("全选")
                        .font(.system(size: 13))
                        .foregroundColor((viewModel.isAllSelected) ? .secondary.opacity(0.5) : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isAllSelected)
                // 🔥 新增：绑定 Command + A 快捷键
                .keyboardShortcut("a", modifiers: .command)
                
                if viewModel.isSelectionMode {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectedVideos.removeAll()
                            viewModel.selectedImages.removeAll()
                        }
                    }) {
                        Text("取消").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 12)
                    .transition(.opacity)
                    // 🔥 新增：绑定 Esc 键取消选择
                    // （因为这个按钮只有在 isSelectionMode 时才会出现，所以 Esc 键也只在选中状态下生效）
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Text("|").foregroundColor(.secondary.opacity(0.3)).padding(.horizontal, 8)
                    
                    let count = viewModel.selectedVideos.count + viewModel.selectedImages.count
                    Text("已选 \(count) 项").font(.system(size: 13)).foregroundColor(.secondary).transition(.opacity)
                }
                
                Spacer()
                
                if viewModel.isSelectionMode {
                    Button(action: {
                        if isSynthesisMode {
                            // 触发黑科技合成操作！
                            viewModel.synthesizeSelectedLivePhoto()
                        } else {
                            // 普通下载操作
                            viewModel.downloadSelected()
                        }
                    }) {
                        HStack {
                            // 使用符号替换动画，在普通图标和 Live 照片图标间丝滑切换
                            Image(systemName: isSynthesisMode ? "livephoto" : "arrow.down.circle.fill")
                                .contentTransition(.symbolEffect(.replace))
                            Text(isSynthesisMode ? "合成保存" : "下载选中")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        // 变身状态：醒目的 Live 照片专属亮黄色
                        .background(isSynthesisMode ? Color(red: 1.0, green: 0.8, blue: 0.0) : AppTheme.accentBlue)
                        .foregroundColor(isSynthesisMode ? .black : .white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    // 监听鼠标悬停，并随时探查 Option 键状态
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHoveringDownloadBtn = hovering
                            isOptionPressed = NSEvent.modifierFlags.contains(.option)
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                Color.clear.frame(height: 32)
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 12)
        .frame(height: 44)
        // 挂载全局键盘监听器，只要按下/松开 Option，UI 立刻响应
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOptionPressed = event.modifierFlags.contains(.option)
                }
                return event
            }
            // 初始化时检查一次
            isOptionPressed = NSEvent.modifierFlags.contains(.option)
        }
        // 离开页面时注意回收监听器资源防内存泄漏
        .onDisappear {
            if let monitor = flagsMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
