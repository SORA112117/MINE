import Foundation
import AVFoundation
import UIKit
import Photos

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
        switch recordType {
        case .video:
            return await generateVideoThumbnail(for: url)
        case .image:
            return await generateImageThumbnail(for: url)
        case .audio:
            return await generateAudioThumbnail(for: url)
        }
    }
    
    func saveToDocuments(data: Data, fileName: String) async throws -> URL {
        let documentsURL = Constants.Storage.documentsDirectory
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    func deleteFile(at url: URL) async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    // MARK: - Private Methods
    
    private func generateVideoThumbnail(for url: URL) async -> URL? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            
            guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
            
            let thumbnailName = url.lastPathComponent.replacingOccurrences(of: ".mp4", with: "_thumb.jpg")
            let thumbnailURL = Constants.Storage.thumbnailsDirectory.appendingPathComponent(thumbnailName)
            
            try data.write(to: thumbnailURL)
            return thumbnailURL
        } catch {
            print("Error generating video thumbnail: \(error)")
            return nil
        }
    }
    
    private func generateImageThumbnail(for url: URL) async -> URL? {
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        
        let targetSize = CGSize(width: 200, height: 200)
        let thumbnail = image.resized(to: targetSize)
        
        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return nil }
        
        let thumbnailName = url.lastPathComponent.replacingOccurrences(of: ".jpg", with: "_thumb.jpg")
        let thumbnailURL = Constants.Storage.thumbnailsDirectory.appendingPathComponent(thumbnailName)
        
        do {
            try data.write(to: thumbnailURL)
            return thumbnailURL
        } catch {
            print("Error generating image thumbnail: \(error)")
            return nil
        }
    }
    
    private func generateAudioThumbnail(for url: URL) async -> URL? {
        // 音声の場合は波形画像を生成（簡易版）
        let waveformImage = generateWaveformPlaceholder()
        
        guard let data = waveformImage.pngData() else { return nil }
        
        let thumbnailName = url.lastPathComponent.replacingOccurrences(of: ".m4a", with: "_wave.png")
        let thumbnailURL = Constants.Storage.thumbnailsDirectory.appendingPathComponent(thumbnailName)
        
        do {
            try data.write(to: thumbnailURL)
            return thumbnailURL
        } catch {
            print("Error generating audio thumbnail: \(error)")
            return nil
        }
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