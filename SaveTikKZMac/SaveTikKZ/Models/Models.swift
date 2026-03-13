//
//  Models.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/8/26.
//

import Foundation

// 1. 核心视频流模型 (对应 Python 的 streams 列表项)
struct VideoStream: Codable, Identifiable {
    let id = UUID() // SwiftUI 列表唯一标识
    
    // UI 展示需要的字段
    let nickname: String
    let create_time: String // 确保不是 createTime
    let width: Int
    let height: Int
    let encoding: String
    let bitRate: Int      // Python 是 bit_rate
    let dataSize: Int     // Python 是 data_size
    let fps: Int
    let isHDR: Bool       // Python 是 is_hdr
    
    
    // 🔥 下载必需字段 (虽然 UI 不显示，但必须存着发回给后端)
    let urlList: [String]
    
    // 键值映射: Python(下划线) <-> Swift(驼峰)
    enum CodingKeys: String, CodingKey {
        case nickname
        case create_time = "create_time"
        case width, height, encoding, fps
        case bitRate = "bit_rate"
        case dataSize = "data_size"
        case isHDR = "is_hdr"
        case urlList = "url_list"
    }
    
    // 辅助属性：生成显示标题
    var displayTitle: String {
        let sizeMB = Double(dataSize) / 1024 / 1024
        return "\(width)x\(height) | \(encoding) | \(String(format: "%.1f MB", sizeMB))"
    }
}

// 2. 解析接口响应
struct ParseResponse: Codable {
    let status: String
    let data: ParseDataContainer
}

struct ParseDataContainer: Codable {
    let streams: [VideoStream]
    // metadata 暂时用字典接收，如果 Python 返回的是复杂结构，这里可以改
    let metadata: [String: String]?
}

// 3. 下载接口响应
struct DownloadResponse: Codable {
    let task_id: String
}

// 4. 状态接口响应
struct StatusResponse: Codable {
    let status: String
}
