//
//  ImageGridView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2026.
//

import SwiftUI
import Combine

// MARK: - 自适应紧密瀑布流布局引擎（支持跨列平滑位移动画与自然长宽比）
struct MasonryLayout: Layout {
    var columns: Int
    var spacing: CGFloat
    
    struct CacheData {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var totalHeight: CGFloat = 0
    }
    
    func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        guard !subviews.isEmpty else {
            cache = CacheData()
            return .zero
        }
        
        let colCount = max(1, columns)
        let totalWidth = proposal.width ?? 500
        let colWidth = max(10, (totalWidth - spacing * CGFloat(colCount - 1)) / CGFloat(colCount))
        
        var colHeights = Array(repeating: CGFloat(0), count: colCount)
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        
        for (index, subview) in subviews.enumerated() {
            let col = index % colCount
            let itemSize = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil))
            let x = CGFloat(col) * (colWidth + spacing)
            let y = colHeights[col]
            
            positions.append(CGPoint(x: x, y: y))
            sizes.append(CGSize(width: colWidth, height: itemSize.height))
            
            colHeights[col] += itemSize.height + spacing
        }
        
        let maxHeight = (colHeights.max() ?? spacing) - spacing
        let totalHeight = max(0, maxHeight)
        
        cache = CacheData(positions: positions, sizes: sizes, totalHeight: totalHeight)
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        guard !subviews.isEmpty else { return }
        
        if cache.positions.count != subviews.count {
            _ = sizeThatFits(proposal: ProposedViewSize(bounds.size), subviews: subviews, cache: &cache)
        }
        
        for (index, subview) in subviews.enumerated() {
            guard index < cache.positions.count else { break }
            let pt = cache.positions[index]
            let size = cache.sizes[index]
            
            subview.place(
                at: CGPoint(x: bounds.minX + pt.x, y: bounds.minY + pt.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
        }
    }
}

struct ImageGridView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.colorScheme) var systemColorScheme
    var colorSchemeOverride: ColorScheme? = nil
    
    private var colorScheme: ColorScheme {
        colorSchemeOverride ?? systemColorScheme
    }
    
    @State private var containerWidth: CGFloat = 500
    private let spacing: CGFloat = 16
    
    private var columnCount: Int {
        let minColWidth: CGFloat = viewModel.preferredGridColumns == 2 ? 240 : 160
        let calculatedCount = Int((containerWidth + spacing) / (minColWidth + spacing))
        return max(viewModel.preferredGridColumns, max(1, calculatedCount))
    }
    
    var body: some View {
        MasonryLayout(columns: columnCount, spacing: spacing) {
            ForEach(Array(viewModel.displayedImages.enumerated()), id: \.element.id) { index, item in
                renderCell(index: index, item: item)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)),
                            removal: .opacity.combined(with: .scale(scale: 0.94))
                        )
                    )
            }
        }
        .padding(.top, 5)
        .padding(.vertical, 10)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in containerWidth = newWidth }
            }
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: columnCount)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: viewModel.displayedImages)
    }
    
    @ViewBuilder
    private func renderCell(index: Int, item: ImageItem) -> some View {
        ImageGridCell(
            index: index + 1,
            item: item,
            isSelected: viewModel.selectedImages.contains(item.id),
            isSelectionMode: viewModel.isSelectionMode,
            colorScheme: colorScheme,
            isLiveMode: Binding(
                get: { viewModel.imageLiveModes[item.id] ?? false },
                set: { viewModel.imageLiveModes[item.id] = $0 }
            ),
            // 🔥 将 ViewModel 里的 User-Agent 传给 Cell
            userAgent: viewModel.currentMetadata["user_agent"],
            onSelectToggle: { viewModel.toggleImageSelection(for: item.id) },
            onDownloadSingle: { viewModel.downloadSingleImage(image: item) }
        )
    }
}
