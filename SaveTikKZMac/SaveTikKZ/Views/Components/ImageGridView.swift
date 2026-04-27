//
//  ImageGridView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2026.
//

import SwiftUI

struct ImageGridView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var containerWidth: CGFloat = 500
    private let spacing: CGFloat = 16
    
    private var columnCount: Int {
        let minColWidth: CGFloat = viewModel.preferredGridColumns == 2 ? 240 : 160
        let calculatedCount = Int((containerWidth + spacing) / (minColWidth + spacing))
        return max(viewModel.preferredGridColumns, calculatedCount)
    }
    
    private func columnsData() -> [[(Int, ImageItem)]] {
        let count = columnCount
        var cols: [[(Int, ImageItem)]] = Array(repeating: [], count: count)
        for (index, item) in viewModel.imageList.enumerated() {
            cols[index % count].append((index, item))
        }
        return cols
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            let currentCols = columnsData()
            
            ForEach(0..<columnCount, id: \.self) { colIndex in
                LazyVStack(spacing: spacing) {
                    ForEach(currentCols[colIndex], id: \.1.id) { index, item in
                        renderCell(index: index, item: item)
                    }
                }
            }
        }
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
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: columnCount)
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
