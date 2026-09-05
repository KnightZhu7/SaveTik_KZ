//
//  ImageCacheManager.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2026.
//

import Foundation
import AppKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        // 设置缓存上限（最多缓存 200 张图片）
        cache.countLimit = 200
    }
    
    /// 获取内存中的图片
    func image(for url: String) -> NSImage? {
        cache.object(forKey: url as NSString)
    }
    
    /// 手动存入缓存
    func storeImage(_ image: NSImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
    
    /// 清除所有缓存
    func clearCache() {
        cache.removeAllObjects()
    }
    
    /// 并发预载一组图片，并自动根据物理像素校验与纠正长宽比
    /// - Parameters:
    ///   - items: 解析得到的图片模型列表
    ///   - userAgent: 请求所需的 User-Agent
    ///   - onProgress: 进度回调 (已完成数, 总数)
    /// - Returns: 校准了真实尺寸后的图片模型列表
    func preloadImages(
        items: [ImageItem],
        userAgent: String?,
        onProgress: ((_ completed: Int, _ total: Int) -> Void)? = nil
    ) async -> [ImageItem] {
        guard !items.isEmpty else { return [] }
        
        let total = items.count
        var correctedItems = items
        
        let ua = userAgent ?? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        
        await withTaskGroup(of: (Int, ImageItem, NSImage?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    // 1. 如果已经在缓存中，直接读取
                    if let cached = self.image(for: item.imageUrl) {
                        var updated = item
                        let size = self.extractPhysicalSize(from: cached, fallback: CGSize(width: item.width, height: item.height))
                        updated.width = Int(size.width)
                        updated.height = Int(size.height)
                        return (index, updated, cached)
                    }
                    
                    // 2. 否则通过网络并发下载
                    guard let url = URL(string: item.imageUrl) else {
                        return (index, item, nil)
                    }
                    
                    var request = URLRequest(url: url)
                    request.setValue(ua, forHTTPHeaderField: "User-Agent")
                    request.setValue("https://www.douyin.com/", forHTTPHeaderField: "Referer")
                    
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
                           let img = NSImage(data: data) {
                            self.storeImage(img, for: item.imageUrl)
                            
                            var updated = item
                            let size = self.extractPhysicalSize(from: img, fallback: CGSize(width: item.width, height: item.height))
                            updated.width = Int(size.width)
                            updated.height = Int(size.height)
                            return (index, updated, img)
                        }
                    } catch {
                        print("[ImageCacheManager] 图片加载失败: \(item.imageUrl), 错误: \(error)")
                    }
                    
                    return (index, item, nil)
                }
            }
            
            var completedCount = 0
            for await (idx, updatedItem, _) in group {
                completedCount += 1
                correctedItems[idx] = updatedItem
                onProgress?(completedCount, total)
            }
        }
        
        return correctedItems
    }
    
    /// 从 NSImage 提取真实物理像素尺寸（优先取图像表示的 pixelsWide / pixelsHigh，防止元数据错误）
    private func extractPhysicalSize(from image: NSImage, fallback: CGSize) -> CGSize {
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        if image.size.width > 0 && image.size.height > 0 {
            return image.size
        }
        return fallback
    }
}
