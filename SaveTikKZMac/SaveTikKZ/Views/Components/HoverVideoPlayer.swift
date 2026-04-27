//
//  HoverVideoPlayer.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 4/27/26.
//

import SwiftUI
import AVKit

struct HoverVideoPlayer: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none // 隐藏播放进度条和按钮
        view.videoGravity = .resizeAspectFill
        view.player = player
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
