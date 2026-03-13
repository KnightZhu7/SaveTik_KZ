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
    let id = UUID()
    let message: String
    let type: LogType
    let time = Date()
    
    // 格式化时间显示 (例如 12:30:05)
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: time)
    }
}
