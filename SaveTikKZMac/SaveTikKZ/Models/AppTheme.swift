//
//  AppTheme.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

// MARK: - 样式与主题配置
struct AppTheme {
    // 🔥 从 Assets.xcassets 读取你设置好的 accentBlue
    static let accentBlue = Color("AccentColor")
    
    static func backgroundColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(nsColor: .windowBackgroundColor)
    }
    
    static func cardColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.125, green: 0.125, blue: 0.125) : Color.white
    }
    
    static func borderColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.215, green: 0.215, blue: 0.215) : Color(nsColor: .separatorColor)
    }
    
    static func hoverColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.16) : Color(nsColor: .controlBackgroundColor)
    }
}

// MARK: - 外观模式枚举
enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色模式"
    case dark = "深色模式"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
    
    // 关键：System 返回 nil，SwiftUI 才会把控制权交还给系统
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
