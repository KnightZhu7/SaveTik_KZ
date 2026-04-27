//
//  MediaCacheManager.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 4/26/26.
//

import Foundation

class MediaCacheManager {
    static let shared = MediaCacheManager()
    private let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SaveTikKZ_Cache", isDirectory: true)
    
    init() {
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    // 🔥 新增 userAgent 参数
    func downloadMedia(url: String, suffix: String, userAgent: String? = nil) async throws -> URL {
        guard let reqUrl = URL(string: url) else { throw URLError(.badURL) }
        let fileName = UUID().uuidString + suffix
        let destURL = tempDir.appendingPathComponent(fileName)
        
        var request = URLRequest(url: reqUrl)
        
        // 🔥 优先使用 Python 后端传来的真实 User-Agent，如果没有再使用兜底的
        let ua = userAgent ?? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        request.setValue(ua, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")
        
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        
        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode != 200 {
            print("下载失败，服务器返回 HTTP 状态码: \(httpRes.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        return destURL
    }
    
    func clearCache() {
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
}
