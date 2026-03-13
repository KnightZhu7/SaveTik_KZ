//
//  APIService.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/8/26.
//

import Foundation

// MARK: - 请求体结构 (专用)
// 这个结构体 Models.swift 里没有，所以我们在文件内部私有定义，
// 专门用来把数据打包发给 Python 的 /download 接口
private struct DownloadRequestBody: Encodable {
    let stream_info: VideoStream
    let metadata: [String: String]
}

// MARK: - API 服务主类
class APIService {
    static let shared = APIService()
    
    // 动态 baseURL，默认为空，等待 PythonManager 启动后通过 setPort 注入
    var baseURL = ""
    
    // 1. 设置端口 (由 PythonManager 调用)
    func setPort(_ port: UInt16) {
        self.baseURL = "http://127.0.0.1:\(port)"
        print("✅ Swift API 目标地址已更新: \(self.baseURL)")
    }
    
    // 2. 解析视频接口
    func parse(url: String) async throws -> ([VideoStream], [String: String]?) {
        // 安全检查：防止后端未启动时发起请求
        guard !baseURL.isEmpty else {
            throw NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "后端服务尚未就绪"])
        }
        
        guard let endpoint = URL(string: "\(baseURL)/parse") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构造 JSON: {"url": "..."}
        let body = ["url": url]
        request.httpBody = try JSONEncoder().encode(body)
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 检查 HTTP 状态码
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            // 如果解析失败，尝试解码错误信息，或者直接抛出错误
            throw URLError(.badServerResponse)
        }
        
        // 解码: 使用 Models.swift 中定义的 ParseResponse
        let decoded = try JSONDecoder().decode(ParseResponse.self, from: data)
        return (decoded.data.streams, decoded.data.metadata)
    }
    
    // 3. 发送下载指令接口
    func download(stream: VideoStream, metadata: [String: String]?) async throws -> String {
        guard !baseURL.isEmpty else { throw URLError(.badURL) }
        guard let endpoint = URL(string: "\(baseURL)/download") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 使用本文件开头定义的私有结构体打包数据
        let requestBody = DownloadRequestBody(
            stream_info: stream,
            metadata: metadata ?? [:]
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        // 解码: 使用 Models.swift 中定义的 DownloadResponse
        let decoded = try JSONDecoder().decode(DownloadResponse.self, from: data)
        return decoded.task_id
    }
    
    // 4. 查询状态接口
    func checkStatus(taskId: String) async throws -> String {
        // 轮询时不抛错，如果未连接直接返回等待
        guard !baseURL.isEmpty else { return "waiting" }
        
        guard let endpoint = URL(string: "\(baseURL)/status/\(taskId)") else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: endpoint)
        
        // 解码: 使用 Models.swift 中定义的 StatusResponse
        let decoded = try JSONDecoder().decode(StatusResponse.self, from: data)
        return decoded.status
    }
}
