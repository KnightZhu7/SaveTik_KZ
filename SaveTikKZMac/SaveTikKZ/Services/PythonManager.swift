//
//  PythonManager.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 2/8/26.
//

import Foundation
import Network

class PythonManager {
    static let shared = PythonManager()
    private var process: Process?
    
    // 获取打包在 App 资源里的可执行文件路径
    private var executablePath: URL? {
            // 1. 先找到 api_server 文件夹 (注意：这是蓝色的那个文件夹)
            guard let folderUrl = Bundle.main.url(forResource: "api_server", withExtension: nil) else {
                print("❌ 错误：在 Bundle 中找不到 api_server 文件夹！")
                return nil
            }
            
            // 2. 指向文件夹内部的同名二进制文件
            // 结构是：api_server(文件夹) -> api_server(可执行文件)
            let binaryUrl = folderUrl.appendingPathComponent("api_server")
            
            // 3. (可选) 做个双重检查，确保文件真的存在
            if !FileManager.default.fileExists(atPath: binaryUrl.path) {
                print("❌ 错误：文件夹找到了，但里面的 api_server 可执行文件不见了！路径: \(binaryUrl.path)")
                return nil
            }
            
            return binaryUrl
    }
    
    // 🔥 黑科技：寻找系统当前的空闲端口
    private func findFreePort() -> UInt16 {
        var port: UInt16 = 8000 // 保底
        
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        if socketFileDescriptor == -1 { return port }
        
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // 绑定到 0，让系统随机分配
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        
        // 尝试绑定
        let bindResult = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if bindResult == 0 {
            // 获取系统分配的端口号
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            getsockname(socketFileDescriptor, withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
            }, &len)
            port = UInt16(bigEndian: addr.sin_port)
        }
        
        close(socketFileDescriptor)
        return port
    }
    
    // 启动 Python 后端
    func start() {
        guard let path = executablePath else {
            print("❌ 严重错误：找不到 api_server 文件！请确认已将打包好的文件拖入 Xcode 并勾选 Add to targets。")
            return
        }
        
        if process != nil && process!.isRunning {
            print("⚠️ 后端已经在运行中，跳过启动")
            return
        }
        
        // 1. 找到一个空闲端口
        let port = findFreePort()
        print("🔍 申请到空闲端口: \(port)")
        
        // 2. 告诉 APIService 以后用这个端口
        APIService.shared.setPort(port)
        
        // 3. 启动进程
        process = Process()
        process?.executableURL = path
        // 🔥 关键：把端口传给 Python
        process?.arguments = ["--port", "\(port)"]
        
        // 配置管道以便在 Xcode 控制台看到 Python 的 print
        let pipe = Pipe()
        process?.standardOutput = pipe
        process?.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak fileHandle] _ in
            guard let fh = fileHandle else { return }
            let data = fh.availableData
            guard !data.isEmpty,
                  let line = String(data: data, encoding: .utf8),
                  !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            print("[Python]: \(line.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        
        do {
            try process?.run()
            print("✅ Python 后端已启动 (PID: \(process?.processIdentifier ?? 0))")
        } catch {
            print("❌ 启动 Python 后端失败: \(error)")
        }
    }
    
    // 停止 Python 后端
    func stop() {
        // ⚠️ 删除了 p.standardOutput = nil 和 p.standardError = nil
        // 因为进程启动后修改管道会引发系统级 Crash
        
        if let p = process, p.isRunning {
            p.terminate() // 直接发送 SIGTERM 终止进程
            print("🛑 Python 后端已停止")
        }
        
        process = nil
    }
}
