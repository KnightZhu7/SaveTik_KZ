//
//  ImageGridCell.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2026.
//

import SwiftUI
import AVKit
import AppKit

struct ImageGridCell: View {
    let index: Int
    let item: ImageItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let colorScheme: ColorScheme
    
    @Binding var isLiveMode: Bool
    let userAgent: String?
    
    let onSelectToggle: () -> Void
    let onDownloadSingle: () -> Void
    
    @State private var isHovered = false
    
    // 自定义图片加载状态
    @State private var coverImage: NSImage? = nil
    @State private var isImageLoading = false
    @State private var isImageFailed = false
    
    // 播放器状态控制
    @State private var player: AVPlayer?
    @State private var hasPlayedOnce = false
    
    private var aspectRatio: CGFloat {
        guard item.height > 0 else { return 1.0 }
        return CGFloat(item.width) / CGFloat(item.height)
    }
    
    // 固有的属性：判断后端发来的是不是 Live 图
    private var isLivePhoto: Bool {
        item.liveVideoUrl != nil && !(item.liveVideoUrl!.isEmpty)
    }
    
    // 动态属性：是否【表现为】Live 图（同时满足：文件是 Live 图 + 用户开启了 Live 下载开关）
    private var shouldActAsLive: Bool {
        isLivePhoto && isLiveMode
    }
    
    private var badgeBackground: Color {
        colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.9)
    }
    
    private var badgeForeground: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    private var liveOnBackground: Color {
        colorScheme == .dark ? Color(red: 1.0, green: 0.8, blue: 0.0) : Color.yellow
    }
    
    private var liveOnForeground: Color {
        .black
    }
    
    var body: some View {
        ZStack {
            // 1. 底层：自定义带请求头的图片层
            Group {
                if let img = coverImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectToggle() }
                } else if isImageFailed {
                    Rectangle().fill(Color.gray.opacity(0.15))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise.circle").font(.title)
                                Text("加载失败，点击重试").font(.caption)
                            }
                            .foregroundColor(.gray)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await loadCoverImage() } }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.15)).overlay(ProgressView())
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectToggle() }
                }
            }
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // 1.5 🔥 视频预览层
            // 修复：不再用 shouldActAsLive 控制组件挂载，只要是 Live 图就保持在底层树中
            if isLivePhoto, let activePlayer = player {
                HoverVideoPlayer(player: activePlayer)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    // 🔥 核心修改：通过透明度隐式控制。关闭 Live 模式时，直接变为透明！
                    .opacity(shouldActAsLive && (isHovered || !hasPlayedOnce) ? 1.0 : 0.0)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.2), value: shouldActAsLive) // 为开关增加丝滑动画
            }
            
            // 2. 悬停灰色遮罩
            if isHovered && !isSelectionMode {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
                    .allowsHitTesting(false)
            }
            
            // 3. UI 交互层
            VStack {
                HStack(alignment: .center) {
                    Text("\(index)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(badgeForeground)
                        .frame(width: 28, height: 28, alignment: .center)
                        .background(badgeBackground)
                        .clipShape(Circle())
                        .allowsHitTesting(false)
                    
                    Spacer()
                    
                    Button(action: {
                        isSelectionMode ? onSelectToggle() : onDownloadSingle()
                    }) {
                        ZStack {
                            if isSelectionMode {
                                if isSelected {
                                    Image(systemName: "checkmark.app.fill")
                                        .resizable().frame(width: 24, height: 24)
                                        .foregroundColor(AppTheme.accentBlue)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(badgeBackground).scaleEffect(0.8))
                                } else {
                                    Image(systemName: "app")
                                        .resizable().frame(width: 24, height: 24)
                                        .foregroundColor(badgeForeground.opacity(0.6))
                                        .background(RoundedRectangle(cornerRadius: 4).fill(badgeBackground).scaleEffect(0.8))
                                }
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .resizable().frame(width: 26, height: 26)
                                    .foregroundColor(isHovered ? AppTheme.accentBlue : badgeForeground.opacity(0.8))
                                    .background(Circle().fill(badgeBackground).scaleEffect(0.85))
                            }
                        }
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    if isLivePhoto {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) { isLiveMode.toggle() }
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: isLiveMode ? "livephoto" : "livephoto.slash")
                                    .font(.system(size: 10))
                                    .contentTransition(.symbolEffect(.replace))
                                
                                Text(isLiveMode ? "Live" : "JPEG")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(isLiveMode ? liveOnForeground : badgeForeground)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(isLiveMode ? liveOnBackground : badgeBackground)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("JPEG")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(badgeForeground).padding(.horizontal, 6).padding(.vertical, 4)
                            .background(badgeBackground).cornerRadius(6)
                            .allowsHitTesting(false)
                    }
                    
                    Text("\(item.width)x\(item.height)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(badgeForeground).padding(.horizontal, 6).padding(.vertical, 4)
                        .background(badgeBackground).cornerRadius(6)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                    
                    Spacer()
                }
            }
            .padding(10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? AppTheme.accentBlue : Color.clear, lineWidth: isSelected ? 3 : 0)
                .allowsHitTesting(false)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ItemFramePreferenceKey.self,
                    value: [item.id: proxy.frame(in: .named("AppWindowSpace"))]
                )
            }
        )
        // 图片加载任务
        .task(id: item.imageUrl) {
            await loadCoverImage()
        }
        // 🔥 监听：如果用户关闭了 Live 开关
        .onChange(of: isLiveMode) { _, newValue in
            if newValue {
                // 打开时，从零热启动播放
                if player == nil { setupPlayer() }
                player?.seek(to: .zero)
                player?.play()
                hasPlayedOnce = false
            } else {
                // 🔥 修复黑闪：关闭时仅仅暂停（Pause），不销毁播放器！
                // 这样内存中始终保留着视频帧，随开随用！
                player?.pause()
            }
        }
        .onAppear {
            // 只要滑入屏幕就建立预加载引擎
            if isLivePhoto && player == nil {
                setupPlayer()
            }
            // 但只有开关打开时，才自动播放
            if shouldActAsLive {
                player?.play()
            }
        }
        .onDisappear {
            // 真正滑出屏幕外时，才把内存还给系统
            destroyPlayer()
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isHovered = hovering }
            
            guard shouldActAsLive else { return }
            
            if hovering {
                if player == nil { setupPlayer() }
                player?.seek(to: .zero)
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let currentItem = notification.object as? AVPlayerItem, currentItem == player?.currentItem else { return }
            hasPlayedOnce = true
            
            if isHovered {
                player?.seek(to: .zero)
                player?.play()
            } else {
                player?.pause()
            }
        }
    }
    
    // MARK: - 自定义图片加载逻辑
    private func loadCoverImage() async {
        guard coverImage == nil else { return }
        await MainActor.run { isImageLoading = true; isImageFailed = false }
        
        guard let url = URL(string: item.imageUrl) else {
            await MainActor.run { isImageFailed = true; isImageLoading = false }
            return
        }
        
        let ua = userAgent ?? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        var request = URLRequest(url: url)
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
               let img = NSImage(data: data) {
                await MainActor.run {
                    self.coverImage = img
                    self.isImageLoading = false
                }
            } else {
                await MainActor.run {
                    self.isImageFailed = true
                    self.isImageLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.isImageFailed = true
                self.isImageLoading = false
            }
        }
    }
    
    // MARK: - 资源管理
    private func setupPlayer() {
        // 🔥 修复：去掉了 shouldActAsLive 的限制条件
        // 允许视频组件在后台默默缓冲第一帧，确保切换开关时不卡顿
        guard player == nil, isLivePhoto, let urlStr = item.liveVideoUrl, let url = URL(string: urlStr) else { return }
        
        let ua = userAgent ?? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        let headers: [String: String] = [
            "User-Agent": ua,
            "Referer": "https://www.douyin.com/"
        ]
        
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let p = AVPlayer(playerItem: playerItem)
        p.isMuted = true
        self.player = p
    }
    
    private func destroyPlayer() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}
