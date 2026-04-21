//
//  LogModel.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

// MARK: - 下载日志类型
enum LogType {
    case info, success, error, loading, connect
    
    var color: Color {
        switch self {
        case .info: return .secondary
        case .connect: return AppTheme.accentBlue
        case .loading: return AppTheme.accentBlue
        case .success: return .green
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .connect: return "globe"
        case .loading: return "arrow.triangle.2.circlepath"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
}

// MARK: - 日志模型
struct LogEntry: Identifiable {
    let id: UUID
    let message: String
    let type: LogType
    let time: Date
    let timeString: String // 🌟 核心修复：改为常量，避免 SwiftUI 重绘时疯狂计算
    
    // 静态共享保持不变
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    // 手动实现初始化方法，签名与默认构造器保持一致，不影响外部调用
    init(message: String, type: LogType) {
        self.id = UUID()
        self.message = message
        self.type = type
        self.time = Date()
        // 🌟 初始化时仅计算一次
        self.timeString = LogEntry.timeFormatter.string(from: self.time)
    }
}
