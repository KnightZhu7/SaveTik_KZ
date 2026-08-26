//
//  HeaderButtonGroup.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 4/21/26.
//

import SwiftUI
import AppKit
import Combine

struct HeaderButtonGroup: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selectedAppearance: AppAppearance
    @Binding var showFilterPopover: Bool
    
    @State private var appearanceHovered = false
    @State private var filterHovered = false
    
    // 监听 Option 键状态
    @State private var isOptionPressed = false
    @State private var flagsMonitor: Any?
    
    private let hoverInset: CGFloat = 3
    
    var body: some View {
        let isImageMode = !viewModel.imageList.isEmpty
        // 🔥 新增：是否允许使用 Option 筛选功能（必须同时拥有 Live 和 JPEG）
        let canFilterImages = viewModel.hasMixedImageTypes
        
        HStack(spacing: 0) {
            // 按钮 1：筛选 / 网格切换 / Live过滤（左）
            Button {
                if isImageMode {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        // 🔥 修改：只有按下 Option 且 允许筛选 时，才触发过滤
                        if isOptionPressed && canFilterImages {
                            viewModel.imageFilterMode = viewModel.imageFilterMode.next
                        } else {
                            // 否则永远是正常的网格列数切换
                            viewModel.preferredGridColumns = viewModel.preferredGridColumns == 2 ? 3 : 2
                        }
                    }
                } else {
                    showFilterPopover.toggle()
                }
            } label: {
                buttonIcon(
                    // 🔥 修改：图标的显示也加入了 canFilterImages 判断
                    systemName: isImageMode
                        ? ((isOptionPressed && canFilterImages) ? viewModel.imageFilterMode.icon : (viewModel.preferredGridColumns == 2 ? "rectangle.grid.2x2" : "square.grid.3x2"))
                        : "line.3.horizontal.decrease",
                    enabled: isImageMode || !viewModel.videoList.isEmpty,
                    hovered: filterHovered && (isImageMode || !viewModel.videoList.isEmpty),
                    isHighlighted: false
                )
            }
            .buttonStyle(.plain)
            .disabled(!isImageMode && viewModel.videoList.isEmpty)
            .contentShape(Capsule())
            .onHover { filterHovered = $0 }
            .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                FilterPopoverView(viewModel: viewModel)
            }
            // 🔥 修改：悬停提示同样加入了 canFilterImages 判断
            .help(isImageMode ? ((isOptionPressed && canFilterImages) ? "切换过滤模式 (当前: \(filterModeName))" : (viewModel.preferredGridColumns == 2 ? "最少 2 列" : "最少 3 列")) : (!viewModel.videoList.isEmpty ? "筛选" : "暂无内容可筛选"))
            .padding(.leading, hoverInset)
            .padding(.vertical, hoverInset)
            
            // 中间竖线
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 16)
                .opacity((appearanceHovered || (filterHovered && (isImageMode || !viewModel.videoList.isEmpty))) ? 0 : 1)
            
            // 按钮 2：外观切换（右）
            Menu {
                Picker("外观模式", selection: $selectedAppearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.rawValue)
                        }.tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                buttonIcon(
                    systemName: "ellipsis",
                    enabled: true,
                    hovered: appearanceHovered,
                    isHighlighted: false
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .onHover { appearanceHovered = $0 }
            .help("切换外观模式")
            .padding(.trailing, hoverInset)
            .padding(.vertical, hoverInset)
        }
        .glassEffect(.regular, in: .capsule)
        .id(selectedAppearance)
        .animation(.easeInOut(duration: 0.12), value: appearanceHovered)
        .animation(.easeInOut(duration: 0.12), value: filterHovered)
        .onAppear {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOptionPressed = event.modifierFlags.contains(.option)
                }
                return event
            }
            isOptionPressed = NSEvent.modifierFlags.contains(.option)
        }
        .onDisappear {
            if let monitor = flagsMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    // 辅助计算当前筛选模式的中文名称
    private var filterModeName: String {
        switch viewModel.imageFilterMode {
        case .all: return "显示全部"
        case .liveOnly: return "仅 Live 图"
        case .jpegOnly: return "仅静态图"
        }
    }
    
    @ViewBuilder
    private func buttonIcon(
        systemName: String,
        enabled: Bool,
        hovered: Bool,
        isHighlighted: Bool
    ) -> some View {
        let buttonSize: CGFloat = 36
        let hoverWidth  = buttonSize - hoverInset
        let hoverHeight = buttonSize - 2 * hoverInset
        
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(hovered ? 0.14 : 0))
            
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundColor(isHighlighted ? AppTheme.accentBlue : .primary)
                .opacity(enabled ? 1.0 : 0.3)
        }
        .frame(width: hoverWidth, height: hoverHeight)
    }
}
