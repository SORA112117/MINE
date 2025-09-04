import Foundation
import AVFoundation
import UIKit
import Photos
import UniformTypeIdentifiers

// MARK: - Media Service
class MediaService {
    
    // MARK: - Public Methods
    
    func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func requestPhotosPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func generateThumbnail(for url: URL, recordType: RecordType) async -> URL? {
        // バックグラウンドキューで処理
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result: URL?
                switch recordType {
                case .video:
                    result = self.generateVideoThumbnailSync(for: url)
                case .image:
                    result = self.generateImageThumbnailSync(for: url)
                case .audio:
                    result = self.generateAudioThumbnailSync(for: url)
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    func saveToDocuments(data: Data, fileName: String) async throws -> URL {
        // バックグラウンドでファイル書き込み
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let documentsURL = Constants.Storage.documentsDirectory
                    let fileURL = documentsURL.appendingPathComponent(fileName)
                    try data.write(to: fileURL)
                    continuation.resume(returning: fileURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteFile(at url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let fileManager = FileManager.default
                do {
                    if fileManager.fileExists(atPath: url.path) {
                        try fileManager.removeItem(at: url)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Storage Management & Cleanup
    
    func getStorageUsage() async -> StorageInfo {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let fileManager = FileManager.default
                
                let documentsSize = self.getDirectorySize(at: Constants.Storage.documentsDirectory)
                let recordsSize = self.getDirectorySize(at: Constants.Storage.recordsDirectory)
                let thumbnailsSize = self.getDirectorySize(at: Constants.Storage.thumbnailsDirectory)
                
                let totalUsed = documentsSize + recordsSize + thumbnailsSize
                
                let freeVersionLimit = Constants.Storage.freeVersionStorageLimit()
                let isProVersion = KeychainService.shared.isProVersion
                let maxStorage = isProVersion ? Int64.max : freeVersionLimit
                
                let storageInfo = StorageInfo(
                    totalUsed: totalUsed,
                    documentsSize: documentsSize,
                    recordsSize: recordsSize,
                    thumbnailsSize: thumbnailsSize,
                    maxStorage: maxStorage,
                    isProVersion: isProVersion
                )
                
                continuation.resume(returning: storageInfo)
            }
        }
    }
    
    func isStorageLimitReached() async -> Bool {
        let storageInfo = await getStorageUsage()
        return storageInfo.isLimitReached
    }
    
    func cleanupOldFiles(keepRecentCount: Int = 50) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let fileManager = FileManager.default
                    
                    // 古いレコードファイルをクリーンアップ
                    try self.cleanupOldFilesInDirectory(
                        at: Constants.Storage.recordsDirectory,
                        keepRecentCount: keepRecentCount
                    )
                    
                    // 関連するサムネイルもクリーンアップ
                    try self.cleanupOrphanedThumbnails()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateVideoThumbnailSync(for url: URL) -> URL? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // パフォーマンス最適化設定
        imageGenerator.maximumSize = CGSize(width: 400, height: 400) // メモリ使用量削減
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            
            // UIImageの作成を最小限に
            let thumbnailName = url.lastPathComponent.replacingOccurrences(of: ".mp4", with: "_thumb.jpg")
            let thumbnailURL = Constants.Storage.thumbnailsDirectory.appendingPathComponent(thumbnailName)
            
            // メモリ効率的な画像保存
            let destination = CGImageDestinationCreateWithURL(thumbnailURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
            if let destination = destination {
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 0.7
                ]
                CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    return thumbnailURL
                }
            }
            
            return nil
        } catch {
            print("Error generating video thumbnail: \(error)")
            return nil
        }
    }
    
    private func generateImageThumbnailSync(for url: URL) -> URL? {
        // Core Graphicsを直接使用してメモリ効率を向上
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        let targetSize = CGSize(width: 400, height: 400)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height)
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        let thumbnailName = url.lastPathComponent.replacingOccurrences(of: url.pathExtension, with: "_thumb.jpg")
        let thumbnailURL = Constants.Storage.thumbnailsDirectory.appendingPathComponent(thumbnailName)
        
        // メモリ効率的な画像保存
        let destination = CGImageDestinationCreateWithURL(thumbnailURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        if let destination = destination {
            let saveOptions: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.7
            ]
            CGImageDestinationAddImage(destination, cgImage, saveOptions as CFDictionary)
            if CGImageDestinationFinalize(destination) {
                return thumbnailURL
            }
        }
        
        return nil
    }
    
    private func generateAudioThumbnailSync(for url: URL) -> URL? {
        // 音声の場合は波形画像を生成（簡易版）
        let waveformImage = generateWaveformPlaceholder()
        
        let thumbnailName = url.lastPathComponent.replacingOccurrences(of: ".m4a", with: "_wave.png")
        let thumbnailURL = Constants.Storage.thumbnailsDirectory.appendingPathComponent(thumbnailName)
        
        // メモリ効率的なPNG保存
        guard let cgImage = waveformImage.cgImage else { return nil }
        
        let destination = CGImageDestinationCreateWithURL(thumbnailURL as CFURL, UTType.png.identifier as CFString, 1, nil)
        if let destination = destination {
            CGImageDestinationAddImage(destination, cgImage, nil)
            if CGImageDestinationFinalize(destination) {
                return thumbnailURL
            }
        }
        
        return nil
    }
    
    private func generateWaveformPlaceholder() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 背景
            UIColor(Theme.gray2).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 波形のプレースホルダー
            UIColor(Theme.primary).setStroke()
            let path = UIBezierPath()
            
            for i in 0..<20 {
                let x = CGFloat(i) * 10
                let height = CGFloat.random(in: 20...100)
                let y = (size.height - height) / 2
                
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + height))
            }
            
            path.lineWidth = 2
            path.stroke()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else { continue }
            totalSize += Int64(fileSize)
        }
        return totalSize
    }
    
    private func cleanupOldFilesInDirectory(at url: URL, keepRecentCount: Int) throws {
        let fileManager = FileManager.default
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        // 作成日時でソート（新しい順）
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            return date1 > date2
        }
        
        // 古いファイルを削除（keepRecentCount個以降）
        if sortedFiles.count > keepRecentCount {
            let filesToDelete = sortedFiles.dropFirst(keepRecentCount)
            for file in filesToDelete {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    private func cleanupOrphanedThumbnails() throws {
        let fileManager = FileManager.default
        let recordsDir = Constants.Storage.recordsDirectory
        let thumbnailsDir = Constants.Storage.thumbnailsDirectory
        
        guard let recordFiles = try? fileManager.contentsOfDirectory(at: recordsDir, includingPropertiesForKeys: nil),
              let thumbnailFiles = try? fileManager.contentsOfDirectory(at: thumbnailsDir, includingPropertiesForKeys: nil) else {
            return
        }
        
        // 対応するレコードファイルがないサムネイルを削除
        let recordNames = Set(recordFiles.map { $0.lastPathComponent })
        
        for thumbnail in thumbnailFiles {
            let thumbnailName = thumbnail.lastPathComponent
            let baseRecordName = thumbnailName
                .replacingOccurrences(of: "_thumb.jpg", with: ".mp4")
                .replacingOccurrences(of: "_thumb.jpg", with: ".m4a")
                .replacingOccurrences(of: "_wave.png", with: ".m4a")
            
            if !recordNames.contains(baseRecordName) {
                try? fileManager.removeItem(at: thumbnail)
            }
        }
    }
}

// MARK: - Storage Info Model
struct StorageInfo {
    let totalUsed: Int64
    let documentsSize: Int64
    let recordsSize: Int64
    let thumbnailsSize: Int64
    let maxStorage: Int64
    let isProVersion: Bool
    
    var availableStorage: Int64 {
        maxStorage == Int64.max ? Int64.max : max(0, maxStorage - totalUsed)
    }
    
    var usagePercentage: Double {
        maxStorage == Int64.max ? 0.0 : min(1.0, Double(totalUsed) / Double(maxStorage))
    }
    
    var isLimitReached: Bool {
        maxStorage != Int64.max && totalUsed >= maxStorage
    }
    
    var formattedTotalUsed: String {
        ByteCountFormatter.string(fromByteCount: totalUsed, countStyle: .file)
    }
    
    var formattedMaxStorage: String {
        maxStorage == Int64.max ? "無制限" : ByteCountFormatter.string(fromByteCount: maxStorage, countStyle: .file)
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}