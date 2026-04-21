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
                Image(systemName: viewModel.statusIcon)
                    .foregroundColor(viewModel.statusColor)
                Text(viewModel.statusMessage)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .frame(width: 12, height: 12)
                    .padding(.leading, 2)
                    .rotationEffect(.degrees(showLogPopover ? 180 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showLogPopover)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { showLogPopover.toggle() }
        .popover(isPresented: $showLogPopover, arrowEdge: .bottom) {
                // 只传值类型快照，不把 ViewModel 引用传进 popover
                LogPopoverView(
                    logs: viewModel.logs,
                    onClear: { [weak viewModel] in    // 🌟 核心修复：弱引用捕获
                        viewModel?.clearLogs()
                    }
                )
            }
        .animation(.easeInOut(duration: 0.2), value: showLogPopover)
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
                }
            }
            .padding(20)
            .frame(width: 380, height: 300)
        }
    }
}
