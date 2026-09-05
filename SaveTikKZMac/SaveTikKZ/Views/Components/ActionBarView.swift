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
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.selectedVideos.removeAll()
                                viewModel.selectedImages.removeAll()
                            }
                        }) {
                            Text("取消").font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 12)
                        // 🔥 新增：绑定 Esc 键取消选择
                        .keyboardShortcut(.escape, modifiers: [])
                        
                        Text("|").foregroundColor(.secondary.opacity(0.3)).padding(.horizontal, 8)
                        
                        let count = viewModel.selectedVideos.count + viewModel.selectedImages.count
                        HStack(spacing: 0) {
                            Text("已选 ")
                            BlurRollingNumberView(value: count, font: .system(size: 13).monospacedDigit(), color: .secondary)
                            Text(" 项")
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: count)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .modifier(
                                active: BlurFadeModifier(opacity: 0, blur: 5),
                                identity: BlurFadeModifier(opacity: 1, blur: 0)
                            ),
                            removal: .modifier(
                                active: BlurFadeModifier(opacity: 0, blur: 5),
                                identity: BlurFadeModifier(opacity: 1, blur: 0)
                            )
                        )
                    )
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isSelectionMode)
        // 挂载全局键盘监听器，只要按下/松开 Option，UI 立刻响应
        .onAppear {
            if let monitor = flagsMonitor {
                NSEvent.removeMonitor(monitor)
            }
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
                flagsMonitor = nil
            }
        }
    }
}

// MARK: - iOS / 时钟小组件风格逐位模糊滚动数字组件
struct BlurRollingNumberView: View {
    let value: Int
    var font: Font = .system(size: 13).monospacedDigit()
    var color: Color = .secondary
    
    @State private var previousValue: Int = 0
    
    private var isIncrementing: Bool {
        value >= previousValue
    }
    
    struct DigitEntry: Identifiable, Equatable {
        let place: Int
        let digit: Int
        var id: Int { place }
    }
    
    private var digits: [DigitEntry] {
        if value <= 0 {
            return [DigitEntry(place: 0, digit: 0)]
        }
        var temp = value
        var result: [DigitEntry] = []
        var place = 0
        while temp > 0 {
            result.append(DigitEntry(place: place, digit: temp % 10))
            temp /= 10
            place += 1
        }
        return result.reversed()
    }
    
    var body: some View {
        HStack(spacing: 0.5) {
            ForEach(digits) { entry in
                RollingDigitSlot(
                    digit: entry.digit,
                    isIncrementing: isIncrementing,
                    font: font,
                    color: color
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.7).combined(with: .opacity),
                    removal: .scale(scale: 0.7).combined(with: .opacity)
                ))
            }
        }
        .onChange(of: value) { oldValue, newValue in
            previousValue = oldValue
        }
        .onAppear {
            previousValue = value
        }
    }
}

private struct RollingDigitSlot: View {
    let digit: Int
    let isIncrementing: Bool
    let font: Font
    let color: Color
    
    var body: some View {
        ZStack {
            Text("\(digit)")
                .font(font)
                .foregroundColor(color)
                .id(digit)
                .transition(
                    .asymmetric(
                        insertion: .modifier(
                            active: BlurOffsetModifier(offset: isIncrementing ? 12 : -12, opacity: 0, blur: 3.5),
                            identity: BlurOffsetModifier(offset: 0, opacity: 1, blur: 0)
                        ),
                        removal: .modifier(
                            active: BlurOffsetModifier(offset: isIncrementing ? -12 : 12, opacity: 0, blur: 3.5),
                            identity: BlurOffsetModifier(offset: 0, opacity: 1, blur: 0)
                        )
                    )
                )
        }
        .frame(height: 20)
        .clipped()
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.18),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: digit)
    }
}

private struct BlurOffsetModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double
    let blur: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .blur(radius: blur)
    }
}

private struct BlurFadeModifier: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
    }
}

