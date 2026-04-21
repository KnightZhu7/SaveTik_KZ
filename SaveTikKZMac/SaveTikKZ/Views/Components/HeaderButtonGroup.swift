//
//  HeaderButtonGroup.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 4/21/26.
//

import SwiftUI

struct HeaderButtonGroup: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selectedAppearance: AppAppearance
    @Binding var showFilterPopover: Bool
    
    @State private var appearanceHovered = false
    @State private var filterHovered = false
    
    private let hoverInset: CGFloat = 3
    
    var body: some View {
        HStack(spacing: 0) {
            // 按钮 1：筛选（左）
            Button {
                showFilterPopover.toggle()
            } label: {
                buttonIcon(
                    systemName: "line.3.horizontal.decrease",
                    enabled: viewModel.hasResults,
                    hovered: filterHovered && viewModel.hasResults
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.hasResults)
            // 限制点击与悬停热区为胶囊形状
            .contentShape(Capsule())
            .onHover { filterHovered = $0 }
            // 修复 1：利用覆盖层创建一个严格等于胶囊尺寸(33x30)的透明锚点，确保弹窗箭头绝对居中
            .overlay {
                Color.clear
                    .frame(width: 36 - hoverInset, height: 36 - 2 * hoverInset)
                    .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                        FilterPopoverView(viewModel: viewModel)
                    }
            }
            .help(viewModel.hasResults ? "筛选" : "暂无视频可筛选")
            // 将原有的左侧对齐留白提取到外面，不参与点击和悬停判定
            .padding(.leading, hoverInset)
            .padding(.vertical, hoverInset)
            
            // 中间竖线
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 16)
                // 修复 2：增加 && viewModel.hasResults 判定，灰色禁用时悬停不再隐藏竖线
                .opacity((appearanceHovered || (filterHovered && viewModel.hasResults)) ? 0 : 1)
            
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
                    hovered: appearanceHovered
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .onHover { appearanceHovered = $0 }
            .help("切换外观模式")
            // 将原有的右侧对齐留白提取到外面
            .padding(.trailing, hoverInset)
            .padding(.vertical, hoverInset)
        }
        .glassEffect(.regular, in: .capsule)
        .id(selectedAppearance)
        .animation(.easeInOut(duration: 0.12), value: appearanceHovered)
        .animation(.easeInOut(duration: 0.12), value: filterHovered)
    }
    
    @ViewBuilder
    private func buttonIcon(
        systemName: String,
        enabled: Bool,
        hovered: Bool
    ) -> some View {
        let buttonSize: CGFloat = 36
        // 核心视觉大小：宽 33, 高 30
        let hoverWidth  = buttonSize - hoverInset
        let hoverHeight = buttonSize - 2 * hoverInset
        
        // 删除了外层的 36x36 Color.clear 占位，让 ZStack 直接等同于胶囊尺寸
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(hovered ? 0.14 : 0))
            
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .opacity(enabled ? 1.0 : 0.3)
        }
        .frame(width: hoverWidth, height: hoverHeight)
    }
}
