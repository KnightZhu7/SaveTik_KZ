//
//  ContentViewModel.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI
import Combine
import AppKit // 需要用到 NSPasteboard 读取剪贴板

@MainActor
class ContentViewModel: ObservableObject {
    // --- 核心数据状态 ---
    @Published var urlInput: String = ""
    @Published var isFetching: Bool = false
    @Published var videoList: [VideoStream] = []
    @Published var selectedVideos: Set<UUID> = []
    @Published var currentMetadata: [String: String] = [:]
    
    // --- 筛选与排序状态 ---
    @Published var showOnlyHighestBitrate: Bool = false {
        didSet { clearSelectionOnFilterChange() }
    }
    @Published var primarySort: SortPriority = .resolution {
        didSet { clearSelectionOnFilterChange() }
    }
    @Published var resolutionTokens: [FilterToken] = [] {
        didSet { clearSelectionOnFilterChange() }
    }
    @Published var encodingTokens: [FilterToken] = [] {
        didSet { clearSelectionOnFilterChange() }
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
    
    // --- 系统服务状态 ---
    @Published var isBackendOnline: Bool = false
    @Published var startupAttempts: Int = 0
    @Published var hasError: Bool = false

    // --- 计算属性 (纯 UI 状态推导) ---
    var isSelectionMode: Bool { !selectedVideos.isEmpty }
    var isAllSelected: Bool { !displayedVideos.isEmpty && selectedVideos.count == displayedVideos.count }
    var hasResults: Bool { !videoList.isEmpty }
    var shouldShowClearButton: Bool { hasResults || hasError }
    
    // 🔥 核心：完美三级过滤与排序算法
    var displayedVideos: [VideoStream] {
        // 1. 过滤：分辨率和编码的亮灭状态
        var result = videoList.filter { video in
            let resName = "\(min(video.width, video.height))P"
            let isResOn = resolutionTokens.first(where: { $0.name == resName })?.isOn ?? false
            let isEncOn = encodingTokens.first(where: { $0.name == video.encoding })?.isOn ?? false
            return isResOn && isEncOn
        }
        
        // 2. 过滤：仅保留最高码率
        if showOnlyHighestBitrate {
            var grouped: [String: VideoStream] = [:]
            for video in result {
                let key = "\(min(video.width, video.height))P_\(video.encoding)_\(video.isHDR ? "hdr" : "sdr")"
                if let existing = grouped[key] {
                    if video.bitRate > existing.bitRate { grouped[key] = video }
                } else {
                    grouped[key] = video
                }
            }
            result = Array(grouped.values)
        }
        
        // 3. 排序：首级优先级 -> 次级优先级 -> 码率大到小
        result.sort { v1, v2 in
            let resName1 = "\(min(v1.width, v1.height))P"
            let resName2 = "\(min(v2.width, v2.height))P"
            
            let resIndex1 = resolutionTokens.firstIndex(where: { $0.name == resName1 }) ?? 99
            let resIndex2 = resolutionTokens.firstIndex(where: { $0.name == resName2 }) ?? 99
            let encIndex1 = encodingTokens.firstIndex(where: { $0.name == v1.encoding }) ?? 99
            let encIndex2 = encodingTokens.firstIndex(where: { $0.name == v2.encoding }) ?? 99
            
            if primarySort == .resolution {
                if resIndex1 != resIndex2 { return resIndex1 < resIndex2 } // 1. 分辨率
                if encIndex1 != encIndex2 { return encIndex1 < encIndex2 } // 2. 编码
            } else {
                if encIndex1 != encIndex2 { return encIndex1 < encIndex2 } // 1. 编码
                if resIndex1 != resIndex2 { return resIndex1 < resIndex2 } // 2. 分辨率
            }
            // 兜底：码率从大到小
            return v1.bitRate > v2.bitRate
        }
        return result
    }

    // MARK: - Actions (UI 交互响应)
    
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
        
        let newLog = LogEntry(message: message, type: type)
        self.logs.insert(newLog, at: 0)
        
        // 限制日志条数防内存溢出
        if self.logs.count > 50 { self.logs.removeLast() }
    }
    
    func clearLogs() {
        logs.removeAll()
        Task { await checkBackendHealth() }
    }

    func selectAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            let allIDs = displayedVideos.map { $0.id }
            selectedVideos = Set(allIDs)
        }
    }

    func toggleSelection(for id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedVideos.contains(id) {
                selectedVideos.remove(id)
            } else {
                selectedVideos.insert(id)
            }
        }
    }
    
    // MARK: - Networking & Business Logic
    
    func handleFetchAction(resetFocus: () -> Void) {
        if isFetching { return }
        
        if shouldShowClearButton {
            // 🔥 用 withAnimation 包裹清除数据的动作，恢复退场动画
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                urlInput = ""
                videoList = []
                selectedVideos = []
                currentMetadata = [:]
                hasError = false
            }
            updateStatus("准备就绪", type: .info)
            resetFocus()
        } else {
            if urlInput.isEmpty {
                if let clipboard = NSPasteboard.general.string(forType: .string) {
                    urlInput = clipboard
                }
            }
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
        print("发送给后端: \(rawText)")
        
        Task {
            do {
                let (streams, meta) = try await APIService.shared.parse(url: rawText)
                
                // 🔥 用 withAnimation 包裹数据赋值，恢复丝滑的进场动画
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    self.videoList = streams
                    self.currentMetadata = meta ?? [:]
                    
                    let uniqueRes = Array(Set(streams.map { "\(min($0.width, $0.height))P" }))
                        .sorted { (Int($0.dropLast()) ?? 0) > (Int($1.dropLast()) ?? 0) }
                    self.resolutionTokens = uniqueRes.map { FilterToken(name: $0, isOn: true) }
                    
                    let uniqueEnc = Array(Set(streams.map { $0.encoding })).sorted()
                    self.encodingTokens = uniqueEnc.map { FilterToken(name: $0, isOn: true) }
                }
                
                self.updateStatus("解析完成: 获取到 \(streams.count) 个视频源", type: .success)
                self.isFetching = false
            } catch {
                print("Swift 详细报错: \(error)")
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

    func downloadSingle(video: VideoStream, isBatchCall: Bool = false) {
        let index = (displayedVideos.firstIndex(where: { $0.id == video.id }) ?? 0) + 1
        
        if !isBatchCall {
            batchTotal = 1
            batchSuccess = 0
            batchError = 0
            activeTasksCount = 0
        }
        
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

    func downloadSelected() {
        let targets = videoList.filter { selectedVideos.contains($0.id) }
        guard !targets.isEmpty else { return }
        
        if targets.count == 1 {
            downloadSingle(video: targets[0], isBatchCall: false)
            return
        }
        
        batchTotal = targets.count
        batchSuccess = 0
        batchError = 0
        activeTasksCount = 0
        
        updateStatus("开始批量下载 \(batchTotal) 个视频", summary: "准备批量下载...", type: .loading)
        for video in targets { downloadSingle(video: video, isBatchCall: true) }
    }

    private func startPolling(taskId: String, videoIndex: Int) {
        Task {
            var isRunning = true
            while isRunning {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                do {
                    let status = try await APIService.shared.checkStatus(taskId: taskId)
                    if status == "completed" {
                        batchSuccess += 1
                        activeTasksCount -= 1
                        isRunning = false
                        handlePollResult(videoIndex: videoIndex, isSuccess: true)
                    } else if status == "failed" {
                        batchError += 1
                        activeTasksCount -= 1
                        isRunning = false
                        handlePollResult(videoIndex: videoIndex, isSuccess: false)
                    } else {
                        if batchTotal > 1 {
                            let finished = batchSuccess + batchError
                            self.statusMessage = "正在批量下载 (\(finished)/\(batchTotal))..."
                        } else {
                            self.statusMessage = "正在下载视频..."
                        }
                        self.statusIcon = LogType.loading.icon
                        self.statusColor = LogType.loading.color
                    }
                } catch { print("waiting...") }
            }
        }
    }
    
    private func handlePollResult(videoIndex: Int, isSuccess: Bool) {
        let msg = "第 \(videoIndex) 个视频下载" + (isSuccess ? "成功" : "失败")
        if batchTotal == 1 {
            updateStatus(msg, summary: isSuccess ? "下载成功" : "下载失败", type: isSuccess ? .success : .error)
        } else {
            let log = LogEntry(message: msg, type: isSuccess ? .success : .error)
            logs.insert(log, at: 0)
            if logs.count > 50 { logs.removeLast() }
        }
        finalizeBatchIfNeeded()
    }

    private func finalizeBatchIfNeeded() {
        guard activeTasksCount == 0 else { return }
        if batchTotal == 1 { return } // 单个下载不触发总结报告
        
        if batchError > 0 {
            updateStatus("批量任务结束：\(batchSuccess) 成功, \(batchError) 失败",
                         summary: "完成：\(batchSuccess) 成功，\(batchError) 失败",
                         type: .error)
        } else {
            updateStatus("所有视频下载成功",
                         summary: "全部 \(batchTotal) 个视频下载成功",
                         type: .success)
        }
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
                if !isBackendOnline {
                    isBackendOnline = true
                    updateStatus("服务已连接", summary: "准备就绪", type: .info)
                }
            } else { throw URLError(.badServerResponse) }
        } catch {
            if isBackendOnline {
                isBackendOnline = false
                updateStatus("连接中断", summary: "连接断开", type: .error)
            } else {
                startupAttempts += 1
                if startupAttempts <= 5 {
                    updateStatus("正在唤醒后端服务...", summary: "启动中...", type: .loading)
                } else {
                    updateStatus("启动超时，请重启 App", summary: "启动失败", type: .error)
                }
            }
        }
    }
}
