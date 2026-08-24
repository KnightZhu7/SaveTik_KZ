//
//  SaveTikKZApp.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/3/26.
//

import SwiftUI

@main
struct SaveTik_KZApp: App {
    // 🔥 必须有这一行，绑定 AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("SaveTik_ShowMarquee") private var showSelectionMarquee: Bool = false
    
    init() {
        // 1. 永久关闭系统级 URLCache 的内存和磁盘配额
        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .toolbar) {
                Divider()
                Button(showSelectionMarquee ? "Hide Selection Marquee" : "Show Selection Marquee") {
                    showSelectionMarquee.toggle()
                }
                .keyboardShortcut("M", modifiers: [.command, .shift])
            }
        }
    }
}

// 🔥 必须有这个类，负责启动和关闭 Python
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("📱 App 启动，准备唤醒 Python...")
        // 🚀 启动 Python
        PythonManager.shared.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        PythonManager.shared.stop()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
