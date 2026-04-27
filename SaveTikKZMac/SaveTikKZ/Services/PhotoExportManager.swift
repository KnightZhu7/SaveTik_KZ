//
//  PhotoExportManager.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 4/26/26.
//

import Foundation
import Photos
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

class PhotoExportManager {
    static let shared = PhotoExportManager()
    
    private let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("LivePhoto_Paired", isDirectory: true)
    
    init() {
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }
    
    private func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }
    
    func saveImage(imageURL: URL) async throws {
        guard await requestAuthorization() else { throw NSError(domain: "PhotoExport", code: 401, userInfo: [NSLocalizedDescriptionKey: "无相册访问权限"]) }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: imageURL)
        }
    }
    
    func saveLivePhoto(imageURL: URL, videoURL: URL) async throws {
        guard await requestAuthorization() else { throw NSError(domain: "PhotoExport", code: 401, userInfo: [NSLocalizedDescriptionKey: "无相册访问权限"]) }
        
        let assetIdentifier = UUID().uuidString
        let pairedImageURL = tempDir.appendingPathComponent("\(assetIdentifier).jpeg")
        let pairedVideoURL = tempDir.appendingPathComponent("\(assetIdentifier).mov")
        
        try await injectMetadataIntoImage(imageURL: imageURL, outputURL: pairedImageURL, assetIdentifier: assetIdentifier)
        try await injectMetadataIntoVideo(videoURL: videoURL, outputURL: pairedVideoURL, assetIdentifier: assetIdentifier)
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: pairedImageURL, options: nil)
            request.addResource(with: .pairedVideo, fileURL: pairedVideoURL, options: nil)
        }
        
        try? FileManager.default.removeItem(at: pairedImageURL)
        try? FileManager.default.removeItem(at: pairedVideoURL)
    }
    
    private func injectMetadataIntoImage(imageURL: URL, outputURL: URL, assetIdentifier: String) async throws {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
              var imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw NSError(domain: "PhotoExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析图片"])
        }
        
        var makerNote = imageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] ?? [:]
        makerNote["17"] = assetIdentifier
        imageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerNote
        
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NSError(domain: "PhotoExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建输出目标"])
        }
        
        CGImageDestinationAddImage(destination, imageRef, imageProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "PhotoExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片写入失败"])
        }
    }

    private func injectMetadataIntoVideo(videoURL: URL, outputURL: URL, assetIdentifier: String) async throws {
        let asset = AVURLAsset(url: videoURL)
        let reader = try AVAssetReader(asset: asset)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "PhotoExport", code: -1, userInfo: [NSLocalizedDescriptionKey: "找不到视频轨道"])
        }
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        // ==========================================
        // 1. 视频通道
        // ==========================================
        let readerVideoSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerVideoSettings)
        reader.add(videoOutput)

        let videoSize = try await videoTrack.load(.naturalSize)
        let width = Int(abs(videoSize.width))
        let height = Int(abs(videoSize.height))

        let writerVideoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerVideoSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = try await videoTrack.load(.preferredTransform)
        writer.add(videoInput)

        // ==========================================
        // 2. 音频通道
        // ==========================================
        var audioInput: AVAssetWriterInput?
        var audioOutput: AVAssetReaderTrackOutput?
        if let aTrack = audioTrack {
            let aOut = AVAssetReaderTrackOutput(track: aTrack, outputSettings: nil)
            reader.add(aOut)
            audioOutput = aOut
            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            writer.add(aIn)
            audioInput = aIn
        }

        // ==========================================
        // 3. 文件级 header：只写 content.identifier
        // ==========================================
        let assetIdentifierItem = AVMutableMetadataItem()
        assetIdentifierItem.key = "com.apple.quicktime.content.identifier" as NSString
        assetIdentifierItem.keySpace = .quickTimeMetadata
        assetIdentifierItem.value = assetIdentifier as NSString
        assetIdentifierItem.dataType = kCMMetadataBaseDataType_UTF8 as String
        writer.metadata = [assetIdentifierItem]  // ✅ 只有 identifier，不要塞 still-image-time

        // ==========================================
        // 4. ✅ 正确做法：still-image-time 独立 timed metadata track
        // ==========================================
        let stillTimeSpec: NSDictionary = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString:
                "mdta/com.apple.quicktime.still-image-time",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString:
                kCMMetadataBaseDataType_SInt8   // ✅ 必须是 SInt8，不是 UTF-8
        ]
        var stillTimeDesc: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [stillTimeSpec] as CFArray,
            formatDescriptionOut: &stillTimeDesc
        )
        let stillTimeInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: stillTimeDesc)
        writer.add(stillTimeInput)
        let stillTimeAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: stillTimeInput)

        // ==========================================
        // 启动流水线
        // ==========================================
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: .zero)

        let duration = try await asset.load(.duration)

        // ✅ 写入 still-image-time：timeRange.start 就是封面帧时间点
        // 选视频中点（模拟 iOS 相机的默认行为），duration 设为一帧
        let halfDuration = CMTime(seconds: duration.seconds / 2.0, preferredTimescale: 600)
        let oneFPS = CMTime(value: 1, timescale: 30)   // 一帧的时长
        let stillTimeItem = AVMutableMetadataItem()
        stillTimeItem.key = "com.apple.quicktime.still-image-time" as NSString
        stillTimeItem.keySpace = .quickTimeMetadata
        stillTimeItem.value = 0 as NSNumber             // payload 值本身被系统忽略，关键在 timeRange.start
        stillTimeItem.dataType = kCMMetadataBaseDataType_SInt8 as String
        stillTimeAdaptor.append(
            AVTimedMetadataGroup(
                items: [stillTimeItem],
                timeRange: CMTimeRange(start: halfDuration, duration: oneFPS)
            )
        )
        // ✅ 立刻标记完成，metadata track 不需要随视频泵送
        stillTimeInput.markAsFinished()

        // ==========================================
        // 并行泵送 video + audio
        // ==========================================
        let exportBox = UnsafeExportBox(
            writer: writer,
            videoInput: videoInput,
            videoOutput: videoOutput,
            audioInput: audioInput,
            audioOutput: audioOutput
        )

        await withCheckedContinuation { continuation in
            let dispatchGroup = DispatchGroup()

            dispatchGroup.enter()
            exportBox.videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "videoExport")) {
                while exportBox.videoInput.isReadyForMoreMediaData {
                    if let buffer = exportBox.videoOutput.copyNextSampleBuffer() {
                        exportBox.videoInput.append(buffer)
                    } else {
                        exportBox.videoInput.markAsFinished()
                        dispatchGroup.leave()
                        break
                    }
                }
            }

            if let _ = exportBox.audioInput, let _ = exportBox.audioOutput {
                dispatchGroup.enter()
                exportBox.audioInput!.requestMediaDataWhenReady(on: DispatchQueue(label: "audioExport")) {
                    while exportBox.audioInput!.isReadyForMoreMediaData {
                        if let buffer = exportBox.audioOutput!.copyNextSampleBuffer() {
                            exportBox.audioInput!.append(buffer)
                        } else {
                            exportBox.audioInput!.markAsFinished()
                            dispatchGroup.leave()
                            break
                        }
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                exportBox.writer.finishWriting {
                    continuation.resume()
                }
            }
        }

        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "PhotoExport", code: -1)
        }
    }
}

// MARK: - 消除 Swift 6 并发警告的包装器
private struct UnsafeExportBox: @unchecked Sendable {
    let writer: AVAssetWriter
    let videoInput: AVAssetWriterInput
    let videoOutput: AVAssetReaderTrackOutput
    let audioInput: AVAssetWriterInput?
    let audioOutput: AVAssetReaderTrackOutput?
}
