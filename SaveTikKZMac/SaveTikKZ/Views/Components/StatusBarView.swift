//
//  StatusBarView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

struct StatusBarView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var showLogPopover: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            HStack(spacing: 6) {
                StatusIconView(
                    icon: viewModel.statusIcon,
                    color: viewModel.statusColor
                )
                
                AnimatedStatusTextView(message: viewModel.statusMessage)
                
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 12, height: 12)
                    .padding(.leading, 2)
                    .rotationEffect(.degrees(showLogPopover ? 180 : 0))
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: viewModel.statusMessage)
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: viewModel.statusIcon)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showLogPopover)
            Spacer()
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
            LogPopoverView(
                logs: viewModel.logs,
                onClear: { viewModel.clearLogs() }
            )
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .padding(.bottom, 10)
    }
    

    struct LogPopoverView: View {
        let logs: [LogEntry]       // 值类型，复制传入，不保持对 ViewModel 的引用
        let onClear: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("状态日志").font(.headline)
                    Spacer()
                    Button(action: onClear) {
                        Text("清除日志")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(6)
                    }.buttonStyle(.plain)
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
                    .padding(.vertical, 8)
                }
                // 上下边界模糊过渡，与主列表滚动区域视觉保持一致
                .mask(
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: 12)
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 12)
                        }
                        Color.black
                            .frame(width: 16)   // 滚动条区域，始终完全不透明
                    }
                )
            }
            .padding(20)
            .frame(width: 380, height: 300)
        }
    }
}

// MARK: - 状态栏专属平滑图标组件（支持旋转动效与零延迟同位过渡）
struct StatusIconView: View {
    let icon: String
    let color: Color
    
    private var isSpinning: Bool {
        icon.contains("triangle") || icon.contains("circlepath") || icon.contains("trianglehead") || icon.contains("rotate")
    }
    
    var body: some View {
        ZStack {
            if isSpinning {
                SpinningIconView(icon: icon, color: color)
                    .id(icon)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .scale(scale: 0.7).combined(with: .opacity)
                    ))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                    .id(icon)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .scale(scale: 0.7).combined(with: .opacity)
                    ))
            }
        }
        .frame(width: 14, height: 14)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: icon)
    }
}

private struct SpinningIconView: View {
    let icon: String
    let color: Color
    @State private var isSpinning = false
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 12))
            .foregroundColor(color)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear {
                isSpinning = true
            }
    }
}

// MARK: - iOS 风格整体原地模糊溶解状态文字组件（支持“...”动态等待与进度数字独立滚动）
struct AnimatedStatusTextView: View {
    let message: String
    var font: Font = .system(size: 12)
    var color: Color = .secondary
    
    private enum ParsedStatus {
        case standard(text: String, hasEllipsis: Bool)
        case progress(prefix: String, current: Int, suffix: String, hasEllipsis: Bool)
        
        var templateId: String {
            switch self {
            case .standard(let text, let hasEllipsis):
                return "std_\(text)_\(hasEllipsis)"
            case .progress(let prefix, _, let suffix, let hasEllipsis):
                return "prog_\(prefix)_\(suffix)_\(hasEllipsis)"
            }
        }
    }
    
    private static let progressRegex: NSRegularExpression? = {
        let pattern = "^(.*?[\\(（])(\\d+)(\\/\\d+[\\)）])(.*)$"
        return try? NSRegularExpression(pattern: pattern)
    }()
    
    private var parsedStatus: ParsedStatus {
        var baseText = message
        var hasEllipsis = false
        if baseText.hasSuffix("...") {
            baseText = String(baseText.dropLast(3)).trimmingCharacters(in: .whitespaces)
            hasEllipsis = true
        } else if baseText.hasSuffix("…") {
            baseText = String(baseText.dropLast(1)).trimmingCharacters(in: .whitespaces)
            hasEllipsis = true
        }
        
        if let regex = Self.progressRegex,
           let match = regex.firstMatch(in: baseText, range: NSRange(baseText.startIndex..., in: baseText)) {
            let nsString = baseText as NSString
            let prefix = nsString.substring(with: match.range(at: 1))
            let currentStr = nsString.substring(with: match.range(at: 2))
            let totalSuffix = nsString.substring(with: match.range(at: 3))
            let remaining = nsString.substring(with: match.range(at: 4))
            let current = Int(currentStr) ?? 0
            return .progress(
                prefix: prefix,
                current: current,
                suffix: totalSuffix + remaining,
                hasEllipsis: hasEllipsis
            )
        }
        
        return .standard(text: baseText, hasEllipsis: hasEllipsis)
    }
    
    var body: some View {
        let status = parsedStatus
        ZStack {
            Group {
                switch status {
                case .standard(let text, let hasEllipsis):
                    HStack(spacing: 3) {
                        Text(text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(font)
                            .foregroundColor(color)
                        
                        if hasEllipsis {
                            PulsingEllipsisView(color: color)
                                .padding(.leading, 1)
                        }
                    }
                case .progress(let prefix, let current, let suffix, let hasEllipsis):
                    HStack(spacing: 0) {
                        Text(prefix)
                            .lineLimit(1)
                            .font(font)
                            .foregroundColor(color)
                        
                        BlurRollingNumberView(
                            value: current,
                            font: font.monospacedDigit(),
                            color: color
                        )
                        
                        Text(suffix)
                            .lineLimit(1)
                            .font(font.monospacedDigit())
                            .foregroundColor(color)
                        
                        if hasEllipsis {
                            PulsingEllipsisView(color: color)
                                .padding(.leading, 3)
                        }
                    }
                }
            }
            .id(status.templateId)
            .transition(
                .asymmetric(
                    insertion: .modifier(
                        active: OverallBlurModifier(opacity: 0, blur: 5),
                        identity: OverallBlurModifier(opacity: 1, blur: 0)
                    ),
                    removal: .modifier(
                        active: OverallBlurModifier(opacity: 0, blur: 5),
                        identity: OverallBlurModifier(opacity: 1, blur: 0)
                    )
                )
            )
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: status.templateId)
    }
}

// MARK: - iMessage / 苹果风格呼吸跳动三点等待动效
struct PulsingEllipsisView: View {
    var color: Color = .secondary
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<3, id: \.self) { index in
                    let delay = Double(index) * 0.22
                    // 平滑正弦波周期 [0, 1]
                    let progress = (sin((time * 3.8) - delay) + 1.0) / 2.0
                    let opacity = 0.3 + (progress * 0.7)
                    let yOffset = -progress * 1.8
                    
                    Circle()
                        .fill(color)
                        .frame(width: 2.5, height: 2.5)
                        .opacity(opacity)
                        .offset(y: yOffset)
                }
            }
            .offset(y: 2.5) // 与汉字文本基线对齐
        }
    }
}

private struct OverallBlurModifier: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
    }
}



