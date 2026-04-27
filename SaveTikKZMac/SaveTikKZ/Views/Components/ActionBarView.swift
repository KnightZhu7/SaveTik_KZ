//
//  ActionBarView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

struct ActionBarView: View {
    @ObservedObject var viewModel: ContentViewModel
    
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
                    
                    Text("|").foregroundColor(.secondary.opacity(0.3)).padding(.horizontal, 8)
                    
                    let count = viewModel.selectedVideos.count + viewModel.selectedImages.count
                    Text("已选 \(count) 项").font(.system(size: 13)).foregroundColor(.secondary).transition(.opacity)
                }
                
                Spacer()
                
                // (全局 Live 下载开关已移除，由每张图独立控制)
                
                if viewModel.isSelectionMode {
                    Button(action: {
                        viewModel.downloadSelected()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("下载选中")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                Color.clear.frame(height: 32)
            }
        }
        .padding(.horizontal, 60)
        .padding(.top, 12)
        .frame(height: 44)
    }
}
