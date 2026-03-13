//
//  VideoRow.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

struct VideoRow: View {
    let video: VideoStream
    let isSelected: Bool
    let isSelectionMode: Bool
    let colorScheme: ColorScheme
    let onSelectToggle: () -> Void
    let onDownloadSingle: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack { Image(systemName: "film").font(.system(size: 14)).foregroundColor(.secondary) }.frame(width: 44)
            Text("\(min(video.width, video.height))P").font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundColor(.primary).frame(width: 60, alignment: .leading)
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1, height: 14).padding(.leading, 3).padding(.trailing, 15)
            Text("\(video.fps)FPS").font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
            Text(video.encoding).font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary).frame(width: 70, alignment: .leading)
            Text("\(video.bitRate)b").font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
            if video.isHDR {
                Text("HDR").font(.system(size: 10, weight: .bold)).foregroundColor(Color.black.opacity(0.7)).padding(.horizontal, 5).padding(.vertical, 2).background(Color.yellow).cornerRadius(4).padding(.leading, 4)
            }
            Spacer()
            Button(action: { isSelectionMode ? onSelectToggle() : onDownloadSingle() }) {
                ZStack {
                    if isSelectionMode {
                        if isSelected {
                            Image(systemName: "checkmark.app.fill").resizable().frame(width: 20, height: 20).foregroundColor(AppTheme.accentBlue).transition(.scale)
                        } else {
                            Image(systemName: "app").resizable().frame(width: 20, height: 20).foregroundColor(.secondary.opacity(0.5)).transition(.opacity)
                        }
                    } else {
                        Image(systemName: "arrow.down.circle").resizable().frame(width: 20, height: 20).foregroundColor(isHovering ? AppTheme.accentBlue : .secondary).transition(.scale)
                    }
                }
                .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).padding(.trailing, 6)
        }
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(rowBackgroundColor)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? AppTheme.accentBlue : AppTheme.borderColor(for: colorScheme), lineWidth: isSelected ? 1.5 : 1))
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onTapGesture { onSelectToggle() }
        .onHover { isHovering = $0 }
    }
    
    var rowBackgroundColor: Color {
        if isSelected { return AppTheme.accentBlue.opacity(colorScheme == .dark ? 0.15 : 0.08) }
        else if isHovering { return AppTheme.hoverColor(for: colorScheme) }
        else { return AppTheme.cardColor(for: colorScheme) }
    }
}
