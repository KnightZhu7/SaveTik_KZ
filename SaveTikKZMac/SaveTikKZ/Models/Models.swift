//
//  Models.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/8/26.
//

import Foundation

// 1. 核心视频流模型 (保持不变)
struct VideoStream: Codable, Identifiable, Equatable {
    let id = UUID()
    
    let nickname: String
    let create_time: String
    let width: Int
    let height: Int
    let encoding: String
    let bitRate: Int      // Python 是 bit_rate
    let dataSize: Int     // Python 是 data_size
    let fps: Int
    let isHDR: Bool       // Python 是 is_hdr
    
    let urlList: [String]
    
    enum CodingKeys: String, CodingKey {
        case nickname
        case create_time = "create_time"
        case width, height, encoding, fps
        case bitRate = "bit_rate"
        case dataSize = "data_size"
        case isHDR = "is_hdr"
        case urlList = "url_list"
    }
    
    var displayTitle: String {
        let sizeMB = Double(dataSize) / 1024 / 1024
        return "\(width)x\(height) | \(encoding) | \(String(format: "%.1f MB", sizeMB))"
    }
}

// 🔥 新增：图片/Live图流模型
struct ImageItem: Codable, Identifiable, Equatable {
    let id = UUID()
    let imageUrl: String
    var width: Int
    var height: Int
    let liveVideoUrl: String? // Live图独有，可能为空
    
    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case width
        case height
        case liveVideoUrl = "live_video_url"
    }
}

// 2. 解析接口响应
struct ParseResponse: Codable {
    let status: String
    let data: ParseDataContainer
}

// 🔥 修改：适配动态返回的数据结构
struct ParseDataContainer: Codable {
    let mediaType: String            // 新增: "video", "image", 或 "live_photo"
    let metadata: [String: String]?
    
    // 下面两个字段变为可选（Optional），因为它们不会同时存在
    let streams: [VideoStream]?      // 仅当 mediaType == "video" 时存在
    let imageData: [ImageItem]?      // 仅当 mediaType == "image" 或 "live_photo" 时存在
    
    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case metadata
        case streams
        case imageData = "image_data"
    }
}

// 3. 下载接口响应 (保持不变)
struct DownloadResponse: Codable {
    let task_id: String
}

// 4. 状态接口响应 (保持不变)
struct StatusResponse: Codable {
    let status: String
}
