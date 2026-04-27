//
//  ContentViewModel.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI
import Combine
import AppKit

@MainActor
class ContentViewModel: ObservableObject {
    // --- 核心数据状态 ---
    @Published var urlInput: String = ""
    @Published var isFetching: Bool = false
    @Published var videoList: [VideoStream] = []
    @Published var imageList: [ImageItem] = []
    @Published var selectedVideos: Set<UUID> = []
    @Published var selectedImages: Set<UUID> = []
    
    // 🔥 新增：统一管理每张图片的 Live 下载意图 (默认开启)
    @Published var imageLiveModes: [UUID: Bool] = [:]
    
    @Published var currentMetadata: [String: String] = [:]
    
    @Published var preferredGridColumns: Int = UserDefaults.standard.integer(forKey: "SaveTik_GridCols") == 0 ? 2 : UserDefaults.standard.integer(forKey: "SaveTik_GridCols") {
        didSet { UserDefaults.standard.set(preferredGridColumns, forKey: "SaveTik_GridCols") }
    }
    
    // --- 筛选与排序状态 ---
    @Published var showOnlyHighestBitrate: Bool = UserDefaults.standard.bool(forKey: "SaveTik_HighestBitrate") {
        didSet { UserDefaults.standard.set(showOnlyHighestBitrate, forKey: "SaveTik_HighestBitrate"); clearSelectionOnFilterChange() }
    }
    @Published var primarySort: SortPriority = SortPriority(rawValue: UserDefaults.standard.string(forKey: "SaveTik_PrimarySort") ?? "") ?? .resolution {
        didSet { UserDefaults.standard.set(primarySort.rawValue, forKey: "SaveTik_PrimarySort"); clearSelectionOnFilterChange() }
    }
    @Published var resolutionTokens: [FilterToken] = [] { didSet { clearSelectionOnFilterChange() } }
    @Published var encodingTokens: [FilterToken] = [] {
        didSet {
            if !encodingTokens.isEmpty { UserDefaults.standard.set(encodingTokens.map { $0.name }, forKey: "SaveTik_EncodingOrder") }
            clearSelectionOnFilterChange()
        }
    }

    // --- 底部状态栏控制 ---
    @Published var statusMessage: String = "准备就绪"
    @Published var statusIcon: String = "info.circle"
    @Published var statusColor: Color = .secondary
    @Published var logs: [LogEntry] = []
    
    // --- 批量下载追踪 ---
    @Published var activeTasksCount: Int = 0
    @Published var batchTotal = 0
    @Published var batchSuccess = 0
    @Published var batchError = 0
    
    @Published var isBackendOnline: Bool = false
    @Published var startupAttempts: Int = 0
    @Published var hasError: Bool = false

    var isSelectionMode: Bool { !selectedVideos.isEmpty || !selectedImages.isEmpty }
    var isAllSelected: Bool {
        if !displayedVideos.isEmpty { return selectedVideos.count == displayedVideos.count }
        if !imageList.isEmpty { return selectedImages.count == imageList.count }
        return false
    }
    var hasResults: Bool { !videoList.isEmpty || !imageList.isEmpty }
    var shouldShowClearButton: Bool { hasResults || hasError }
    
    var displayedVideos: [VideoStream] {
        var result = videoList.filter { video in
            let resName = "\(min(video.width, video.height))P"
            let isResOn = resolutionTokens.first(where: { $0.name == resName })?.isOn ?? false
            let isEncOn = encodingTokens.first(where: { $0.name == video.encoding })?.isOn ?? false
            return isResOn && isEncOn
        }
        if showOnlyHighestBitrate {
            var grouped: [String: VideoStream] = [:]
            for video in result {
                let key = "\(min(video.width, video.height))P_\(video.encoding)_\(video.isHDR ? "hdr" : "sdr")"
                if let existing = grouped[key] {
                    if video.bitRate > existing.bitRate { grouped[key] = video }
                } else { grouped[key] = video }
            }
            result = Array(grouped.values)
        }
        result.sort { v1, v2 in
            let resName1 = "\(min(v1.width, v1.height))P"
            let resName2 = "\(min(v2.width, v2.height))P"
            let resIndex1 = resolutionTokens.firstIndex(where: { $0.name == resName1 }) ?? 99
            let resIndex2 = resolutionTokens.firstIndex(where: { $0.name == resName2 }) ?? 99
            let encIndex1 = encodingTokens.firstIndex(where: { $0.name == v1.encoding }) ?? 99
            let encIndex2 = encodingTokens.firstIndex(where: { $0.name == v2.encoding }) ?? 99
            
            if primarySort == .resolution {
                if resIndex1 != resIndex2 { return resIndex1 < resIndex2 }
                if encIndex1 != encIndex2 { return encIndex1 < encIndex2 }
            } else {
                if encIndex1 != encIndex2 { return encIndex1 < encIndex2 }
                if resIndex1 != resIndex2 { return resIndex1 < resIndex2 }
            }
            return v1.bitRate > v2.bitRate
        }
        return result
    }

    private func clearSelectionOnFilterChange() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let displayedIDs = Set(displayedVideos.map { $0.id })
            selectedVideos.formIntersection(displayedIDs)
        }
    }

    func updateStatus(_ message: String, summary: String? = nil, type: LogType = .info) {
        self.statusMessage = summary ?? message
        self.statusIcon = type.icon
        self.statusColor = type.color
        self.logs.insert(LogEntry(message: message, type: type), at: 0)
        if self.logs.count > 50 { self.logs.removeLast() }
    }
    
    func clearLogs() { logs.removeAll(); Task { await checkBackendHealth() } }

    func selectAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if !displayedVideos.isEmpty { selectedVideos = Set(displayedVideos.map { $0.id }) }
            else if !imageList.isEmpty { selectedImages = Set(imageList.map { $0.id }) }
        }
    }

    func toggleSelection(for id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedVideos.contains(id) { selectedVideos.remove(id) } else { selectedVideos.insert(id) }
        }
    }
    
    func toggleImageSelection(for id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedImages.contains(id) { selectedImages.remove(id) } else { selectedImages.insert(id) }
        }
    }
    
    func handleFetchAction(resetFocus: () -> Void) {
        if isFetching { return }
        if shouldShowClearButton {
            cancelAllPollingTasks()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                autoreleasepool {
                    self.videoList.removeAll(keepingCapacity: false)
                    self.imageList.removeAll(keepingCapacity: false)
                    self.selectedVideos.removeAll(keepingCapacity: false)
                    self.selectedImages.removeAll(keepingCapacity: false)
                    self.imageLiveModes.removeAll(keepingCapacity: false)
                    self.currentMetadata.removeAll(keepingCapacity: false)
                    self.resolutionTokens.removeAll(keepingCapacity: false)
                    self.encodingTokens.removeAll(keepingCapacity: false)
                    self.urlInput = ""
                    self.hasError = false
                }
            }
            URLCache.shared.removeAllCachedResponses()
            URLCache.shared.memoryCapacity = 0
            URLCache.shared.diskCapacity = 0
            updateStatus("准备就绪", type: .info)
            resetFocus()
            Task {
                await APIService.shared.clearBackendMemory()
                MediaCacheManager.shared.clearCache() // 清理本地缓存
            }
        } else {
            if urlInput.isEmpty { if let clipboard = NSPasteboard.general.string(forType: .string) { urlInput = clipboard } }
            startFetching()
        }
    }

    private func startFetching() {
        guard !urlInput.isEmpty else { return }
        isFetching = true
        updateStatus("正在获取...", type: .connect)
        videoList = []
        selectedVideos = []
        currentMetadata = [:]
        
        let rawText = urlInput
        Task {
            do {
                let responseData = try await APIService.shared.parse(url: rawText)
                if responseData.mediaType == "video" {
                    let streams = responseData.streams ?? []
                    let meta = responseData.metadata
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        self.videoList = streams
                        self.currentMetadata = meta ?? [:]
                        let uniqueRes = Array(Set(streams.map { "\(min($0.width, $0.height))P" })).sorted { (Int($0.dropLast()) ?? 0) > (Int($1.dropLast()) ?? 0) }
                        self.resolutionTokens = uniqueRes.map { FilterToken(name: $0, isOn: true) }
                        let uniqueEnc = Array(Set(streams.map { $0.encoding }))
                        let savedEncOrder = UserDefaults.standard.stringArray(forKey: "SaveTik_EncodingOrder") ?? []
                        let sortedEnc = uniqueEnc.sorted { enc1, enc2 in
                            let idx1 = savedEncOrder.firstIndex(of: enc1) ?? 999
                            let idx2 = savedEncOrder.firstIndex(of: enc2) ?? 999
                            if idx1 != idx2 { return idx1 < idx2 }
                            return enc1 < enc2
                        }
                        self.encodingTokens = sortedEnc.map { FilterToken(name: $0, isOn: true) }
                    }
                    self.updateStatus("解析完成: 获取到 \(streams.count) 个视频源", type: .success)
                    
                } else if responseData.mediaType == "image" || responseData.mediaType == "live_photo" {
                    let images = responseData.imageData ?? []
                    let livePhotoCount = images.filter { $0.liveVideoUrl != nil }.count
                    let normalImageCount = images.count - livePhotoCount
                    
                    var msgParts: [String] = []
                    if normalImageCount > 0 { msgParts.append("\(normalImageCount) 张图片") }
                    if livePhotoCount > 0 { msgParts.append("\(livePhotoCount) 张 Live 图") }
                    let detailStr = msgParts.joined(separator: "，")
                    let displayMessage = detailStr.isEmpty ? "解析完成：未发现图片内容" : "获取到 \(detailStr)"
                    
                    // 初始化每个图片的 Live 模式意图
                    var modes: [UUID: Bool] = [:]
                    for img in images { modes[img.id] = (img.liveVideoUrl != nil) }
                    
                    withAnimation {
                        self.videoList = []
                        self.imageList = images
                        self.imageLiveModes = modes
                        self.resolutionTokens = []
                        self.encodingTokens = []
                        self.currentMetadata = responseData.metadata ?? [:]
                    }
                    self.updateStatus("解析完成：\(displayMessage)", summary: "解析完成: 获取到 \(images.count) 张图片", type: .success)
                } else {
                    self.updateStatus("解析失败：未知的媒体类型", type: .error)
                }
                self.isFetching = false
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == -1011 {
                    self.updateStatus("链接无效，请输入正确的视频链接", type: .error)
                } else {
                    self.updateStatus("出错: \(error.localizedDescription)", type: .error)
                }
                self.hasError = true
                self.isFetching = false
            }
        }
    }

    // MARK: - 下载核心逻辑
    
    // 1. 视频下载
    func downloadSingle(video: VideoStream, isBatchCall: Bool = false) {
        let index = (displayedVideos.firstIndex(where: { $0.id == video.id }) ?? 0) + 1
        if !isBatchCall { batchTotal = 1; batchSuccess = 0; batchError = 0; activeTasksCount = 0 }
        activeTasksCount += 1
        let loadingMsg = isBatchCall ? "准备下载中..." : "正在请求下载第 \(index) 个视频..."
        updateStatus("正在请求第 \(index) 个视频...", summary: loadingMsg, type: .loading)
        
        Task {
            do {
                let taskId = try await APIService.shared.download(stream: video, metadata: self.currentMetadata)
                startPolling(taskId: taskId, videoIndex: index)
            } catch {
                activeTasksCount -= 1
                batchError += 1
                updateStatus("第 \(index) 个视频请求失败: \(error.localizedDescription)", type: .error)
                finalizeBatchIfNeeded()
            }
        }
    }
    
    // 2. 图片/Live图 下载保存到相册
    func downloadSingleImage(image: ImageItem, isBatchCall: Bool = false) {
        let index = (imageList.firstIndex(where: { $0.id == image.id }) ?? 0) + 1
        if !isBatchCall { batchTotal = 1; batchSuccess = 0; batchError = 0; activeTasksCount = 0 }
        
        activeTasksCount += 1
        let isLiveTarget = imageLiveModes[image.id] ?? false
        let loadingMsg = isBatchCall ? "准备保存中..." : "正在下载并保存第 \(index) 张图..."
        updateStatus("正在处理第 \(index) 张图片...", summary: loadingMsg, type: .loading)
        
        // 🔥 获取当前解析任务对应的 User-Agent
        let dynamicUA = self.currentMetadata["user_agent"]
        
        Task {
            do {
                // 传入 dynamicUA
                let localImageURL = try await MediaCacheManager.shared.downloadMedia(url: image.imageUrl, suffix: ".jpeg", userAgent: dynamicUA)
                
                if isLiveTarget, let liveUrl = image.liveVideoUrl {
                    // 🔥 核心修复：如实以 .mp4 保存下载流，避免 AVFoundation 解析轨道失败
                    let localVideoURL = try await MediaCacheManager.shared.downloadMedia(url: liveUrl, suffix: ".mp4", userAgent: dynamicUA)
                    
                    try await PhotoExportManager.shared.saveLivePhoto(imageURL: localImageURL, videoURL: localVideoURL)
                } else {
                    try await PhotoExportManager.shared.saveImage(imageURL: localImageURL)
                }
                
                await MainActor.run {
                    self.batchSuccess += 1
                    self.activeTasksCount -= 1
                    let msg = "第 \(index) 张图" + (isLiveTarget ? " (Live)" : "") + "保存到相册成功"
                    if self.batchTotal == 1 {
                        self.updateStatus(msg, summary: "保存成功", type: .success)
                    } else {
                        self.logs.insert(LogEntry(message: msg, type: .success), at: 0)
                        self.statusMessage = "正在批量保存 (\(self.batchSuccess + self.batchError)/\(self.batchTotal))..."
                    }
                    self.finalizeBatchIfNeeded()
                }
            } catch {
                await MainActor.run {
                    self.activeTasksCount -= 1
                    self.batchError += 1
                    let msg = "第 \(index) 张图保存失败: \(error.localizedDescription)"
                    if self.batchTotal == 1 {
                        self.updateStatus(msg, summary: "保存失败", type: .error)
                    } else {
                        self.logs.insert(LogEntry(message: msg, type: .error), at: 0)
                    }
                    self.finalizeBatchIfNeeded()
                }
            }
        }
    }

    // 3. 触发选中下载 (智能判断视频或图片)
    func downloadSelected() {
        if !selectedVideos.isEmpty {
            let targets = videoList.filter { selectedVideos.contains($0.id) }
            if targets.count == 1 { downloadSingle(video: targets[0], isBatchCall: false); return }
            batchTotal = targets.count; batchSuccess = 0; batchError = 0; activeTasksCount = 0
            updateStatus("开始批量下载 \(batchTotal) 个视频", summary: "准备批量下载...", type: .loading)
            for video in targets { downloadSingle(video: video, isBatchCall: true) }
        }
        else if !selectedImages.isEmpty {
            let targets = imageList.filter { selectedImages.contains($0.id) }
            if targets.count == 1 { downloadSingleImage(image: targets[0], isBatchCall: false); return }
            batchTotal = targets.count; batchSuccess = 0; batchError = 0; activeTasksCount = 0
            updateStatus("开始批量保存 \(batchTotal) 张图片", summary: "批量保存中...", type: .loading)
            for img in targets { downloadSingleImage(image: img, isBatchCall: true) }
        }
    }
    
    private var pollingTasks: [String: Task<Void, Never>] = [:]
    private func startPolling(taskId: String, videoIndex: Int) {
        let task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                do {
                    let status = try await APIService.shared.checkStatus(taskId: taskId)
                    if status == "completed" {
                        await MainActor.run {
                            self.batchSuccess += 1
                            self.activeTasksCount -= 1
                            self.handlePollResult(videoIndex: videoIndex, isSuccess: true)
                            self.pollingTasks.removeValue(forKey: taskId)
                        }
                        break
                    } else if status == "failed" {
                        await MainActor.run {
                            self.batchError += 1
                            self.activeTasksCount -= 1
                            self.handlePollResult(videoIndex: videoIndex, isSuccess: false)
                            self.pollingTasks.removeValue(forKey: taskId)
                        }
                        break
                    } else {
                        await MainActor.run {
                            if self.batchTotal > 1 {
                                let finished = self.batchSuccess + self.batchError
                                self.statusMessage = "正在批量下载 (\(finished)/\(self.batchTotal))..."
                            } else { self.statusMessage = "正在下载视频..." }
                            self.statusIcon = LogType.loading.icon
                            self.statusColor = LogType.loading.color
                        }
                    }
                } catch { }
            }
        }
        pollingTasks[taskId] = task
    }
    
    private func cancelAllPollingTasks() { pollingTasks.values.forEach { $0.cancel() }; pollingTasks.removeAll() }
    
    private func handlePollResult(videoIndex: Int, isSuccess: Bool) {
        let msg = "第 \(videoIndex) 个视频下载" + (isSuccess ? "成功" : "失败")
        if batchTotal == 1 { updateStatus(msg, summary: isSuccess ? "下载成功" : "下载失败", type: isSuccess ? .success : .error) }
        else { self.logs.insert(LogEntry(message: msg, type: isSuccess ? .success : .error), at: 0) }
        finalizeBatchIfNeeded()
    }

    private func finalizeBatchIfNeeded() {
        guard activeTasksCount == 0 else { return }
        if batchTotal <= 1 { return }
        if batchError > 0 { updateStatus("任务结束：\(batchSuccess) 成功, \(batchError) 失败", summary: "完成：\(batchSuccess) 成功，\(batchError) 失败", type: .error) }
        else { updateStatus("所有任务成功", summary: "全部 \(batchTotal) 个任务完成", type: .success) }
    }

    func checkBackendHealth() async {
        if isFetching { return }
        let currentBaseURL = APIService.shared.baseURL
        if currentBaseURL.isEmpty { return }
        guard let url = URL(string: currentBaseURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                startupAttempts = 0
                if !isBackendOnline { isBackendOnline = true; updateStatus("服务已连接", summary: "准备就绪", type: .info) }
            } else { throw URLError(.badServerResponse) }
        } catch {
            if isBackendOnline { isBackendOnline = false; updateStatus("连接中断", summary: "连接断开", type: .error) }
            else {
                startupAttempts += 1
                if startupAttempts <= 5 { updateStatus("正在唤醒后端服务...", summary: "启动中...", type: .loading) }
                else { updateStatus("启动超时，请重启 App", summary: "启动失败", type: .error) }
            }
        }
    }
}
