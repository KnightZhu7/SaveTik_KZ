//
//  FilterPopoverView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

struct FilterPopoverView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Namespace private var animationNamespace
    
    @State private var draggedResToken: FilterToken?
    @State private var draggedEncToken: FilterToken?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("高级筛选与排序").font(.headline)
                Spacer()
                Toggle("仅最高码率", isOn: $viewModel.showOnlyHighestBitrate.animation(.spring(response: 0.3, dampingFraction: 0.7)))
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            Divider()
            
            // 优先级切换
            HStack {
                Text("优先级:").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary).frame(width: 75, alignment: .leading)
                HStack(spacing: 0) {
                    ForEach(SortPriority.allCases) { priority in
                        Text(priority.rawValue)
                            .font(.system(size: 12, weight: viewModel.primarySort == priority ? .bold : .medium))
                            .foregroundColor(viewModel.primarySort == priority ? .white : .primary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                ZStack {
                                    if viewModel.primarySort == priority {
                                        RoundedRectangle(cornerRadius: 6).fill(AppTheme.accentBlue)
                                            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                                            .matchedGeometryEffect(id: "SEGMENT", in: animationNamespace)
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.primarySort = priority } }
                    }
                }
                .padding(2).background(Color.secondary.opacity(0.1)).cornerRadius(8).frame(width: 180)
            }
            
            // 分辨率行
            HStack(spacing: 8) {
                Text("分辨率:").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary).frame(width: 75, alignment: .leading)
                draggableTokenRow(tokens: $viewModel.resolutionTokens, draggedToken: $draggedResToken, isRes: true)
            }
            
            // 编码行
            HStack(spacing: 8) {
                Text("编    码:").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary).frame(width: 75, alignment: .leading)
                draggableTokenRow(tokens: $viewModel.encodingTokens, draggedToken: $draggedEncToken, isRes: false)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
    
    // MARK: - 内部拖拽逻辑
    private func toggleToken(_ token: FilterToken, isRes: Bool) {
        draggedResToken = nil
        draggedEncToken = nil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            var array = isRes ? viewModel.resolutionTokens : viewModel.encodingTokens
            guard let index = array.firstIndex(where: { $0.id == token.id }) else { return }
            if array[index].isOn && array.filter({ $0.isOn }).count == 1 { return }
            array[index].isOn.toggle()
            
            let onTokens  = array.filter { $0.isOn }
            let offTokens = array.filter { !$0.isOn }.sorted { isRes ? ($0.numericValue > $1.numericValue) : ($0.name < $1.name) }
            
            if isRes { viewModel.resolutionTokens = onTokens + offTokens }
            else     { viewModel.encodingTokens = onTokens + offTokens }
        }
    }
    
    @ViewBuilder
    private func draggableTokenRow(tokens: Binding<[FilterToken]>, draggedToken: Binding<FilterToken?>, isRes: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tokens.wrappedValue) { token in
                        TokenChip(token: token, isDragging: draggedToken.wrappedValue?.id == token.id) {
                            toggleToken(token, isRes: isRes)
                        }
                        .id(token.id)
                        .gesture(
                            token.isOn ? DragGesture(minimumDistance: 4, coordinateSpace: .named("hstack_\(isRes)"))
                                .onChanged { value in
                                    if draggedToken.wrappedValue?.id != token.id {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) { draggedToken.wrappedValue = token }
                                    }
                                    reorderTokens(tokens: tokens, dragged: token, xLocation: value.location.x)
                                    
                                    if value.location.x < 50 {
                                        if let idx = tokens.wrappedValue.firstIndex(where: { $0.id == token.id }), idx > 0 {
                                            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(tokens.wrappedValue[idx - 1].id, anchor: .leading) }
                                        }
                                    } else if value.location.x > (380 - 83 - 50) {
                                        if let idx = tokens.wrappedValue.firstIndex(where: { $0.id == token.id }), idx < tokens.wrappedValue.count - 1 {
                                            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(tokens.wrappedValue[idx + 1].id, anchor: .trailing) }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { draggedToken.wrappedValue = nil }
                                } : nil
                        )
                    }
                }
                .padding(.vertical, 2)
                .coordinateSpace(name: "hstack_\(isRes)")
            }
        }
    }
    
    private func reorderTokens(tokens: Binding<[FilterToken]>, dragged: FilterToken, xLocation: CGFloat) {
        var arr = tokens.wrappedValue
        guard let fromIdx = arr.firstIndex(where: { $0.id == dragged.id }) else { return }
        let toIdx = max(0, min(arr.count - 1, Int(xLocation / 64)))
        guard arr[toIdx].isOn, toIdx != fromIdx else { return }
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            arr.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
            tokens.wrappedValue = arr
        }
    }
}

private struct TokenChip: View {
    let token: FilterToken
    let isDragging: Bool
    let onTap: () -> Void

    var body: some View {
        Text(token.name)
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 12, weight: .bold)).padding(.horizontal, 10).padding(.vertical, 4)
            .background(token.isOn ? AppTheme.accentBlue : Color.gray.opacity(0.2))
            .foregroundColor(token.isOn ? .white : .primary.opacity(0.4)).cornerRadius(6)
            .scaleEffect(isDragging ? 1.08 : 1.0)
            .shadow(color: isDragging ? .black.opacity(0.18) : .clear, radius: isDragging ? 6 : 0, x: 0, y: isDragging ? 3 : 0)
            .opacity(isDragging ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
            .onTapGesture { onTap() }
    }
}
