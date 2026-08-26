//
//  MarqueeScrollController.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 8/27/26.
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class MarqueeScrollController: ObservableObject {
    weak var scrollView: NSScrollView?
    
    var scrollOffset: CGFloat {
        scrollView?.contentView.bounds.origin.y ?? 0
    }
    
    var viewportHeight: CGFloat {
        scrollView?.contentView.bounds.height ?? 0
    }
    
    var contentHeight: CGFloat {
        scrollView?.documentView?.bounds.height ?? 0
    }
    
    private var autoScrollTimer: Timer?
    private var currentScrollSpeed: CGFloat = 0
    private var onTick: (() -> Void)?
    
    func attach(scrollView: NSScrollView) {
        self.scrollView = scrollView
    }
    
    @discardableResult
    func scrollBy(deltaY: CGFloat) -> Bool {
        guard let scrollView = scrollView,
              let docView = scrollView.documentView else { return false }
        
        let clipView = scrollView.contentView
        let currentY = clipView.bounds.origin.y
        let maxScrollY = max(0, docView.bounds.height - clipView.bounds.height)
        guard maxScrollY > 0 else { return false }
        
        let targetY = min(max(0, currentY + deltaY), maxScrollY)
        if abs(targetY - currentY) > 0.01 {
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
            return true
        }
        return false
    }
    
    func startAutoScroll(speed: CGFloat, onTick: @escaping () -> Void) {
        self.currentScrollSpeed = speed
        self.onTick = onTick
        
        if autoScrollTimer == nil {
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self else { return }
                    if self.currentScrollSpeed != 0 {
                        let didScroll = self.scrollBy(deltaY: self.currentScrollSpeed)
                        if didScroll {
                            self.onTick?()
                        }
                    }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.autoScrollTimer = timer
        }
    }
    
    func updateAutoScrollSpeed(_ speed: CGFloat) {
        self.currentScrollSpeed = speed
    }
    
    func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        currentScrollSpeed = 0
        onTick = nil
    }
    
    deinit {
        autoScrollTimer?.invalidate()
    }
}

// MARK: - NSViewRepresentable to access enclosing NSScrollView
struct ScrollViewAccessor: NSViewRepresentable {
    let onScrollViewFound: (NSScrollView) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                onScrollViewFound(scrollView)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                onScrollViewFound(scrollView)
            }
        }
    }
}
