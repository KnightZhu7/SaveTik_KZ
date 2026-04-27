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
        let isImageMode = !viewModel.imageList.isEmpty
        
        HStack(spacing: 0) {
            // 按钮 1：筛选 / 网格切换（左）
            Button {
                if isImageMode {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.preferredGridColumns = viewModel.preferredGridColumns == 2 ? 3 : 2
                    }
                } else {
                    showFilterPopover.toggle()
                }
            } label: {
                buttonIcon(
                    systemName: isImageMode
                        ? (viewModel.preferredGridColumns == 2 ? "rectangle.grid.2x2" : "square.grid.3x2")
                        : "line.3.horizontal.decrease",
                    enabled: isImageMode || !viewModel.videoList.isEmpty,
                    hovered: filterHovered && (isImageMode || !viewModel.videoList.isEmpty)
                )
            }
            .buttonStyle(.plain)
            .disabled(!isImageMode && viewModel.videoList.isEmpty)
            .contentShape(Capsule())
            .onHover { filterHovered = $0 }
            .overlay {
                if !isImageMode {
                    Color.clear
                        .frame(width: 36 - hoverInset, height: 36 - 2 * hoverInset)
                        .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                            FilterPopoverView(viewModel: viewModel)
                        }
                }
            }
            // 🔥 修改：根据模式显示更精确的 Help 提示
            .help(isImageMode ? (viewModel.preferredGridColumns == 2 ? "最少 2 列" : "最少 3 列") : (!viewModel.videoList.isEmpty ? "筛选" : "暂无内容可筛选"))
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
                    hovered: appearanceHovered
                )
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .onHover { appearanceHovered = $0 }
            // 🔥 修改：补上外观按钮的 Help 提示
            .help("切换外观模式")
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
        let hoverWidth  = buttonSize - hoverInset
        let hoverHeight = buttonSize - 2 * hoverInset
        
        ZStack {
            Capsule()
                .fill(Color.primary.opacity(hovered ? 0.14 : 0))
            
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundColor(.primary)
                .opacity(enabled ? 1.0 : 0.3)
        }
        .frame(width: hoverWidth, height: hoverHeight)
    }
}
