import Foundation
import UIKit
import AVFoundation
import Photos

// MARK: - Thumbnail Generator Service
class ThumbnailGeneratorService {
    static let shared = ThumbnailGeneratorService()
    
    private init() {}
    
    // サムネイルサイズ
    private let thumbnailSize = CGSize(width: 180, height: 180)
    
    // MARK: - Advanced Thumbnail Generation System (類似システム参考実装)
    func generateThumbnail(for record: Record, completion: @escaping (UIImage?) -> Void) {
        // Phase 1: 即座にキャッシュ確認（Instagram方式）
        if let savedThumbnail = loadSavedThumbnail(for: record.id) {
            DispatchQueue.main.async {
                completion(savedThumbnail)
            }
            return
        }
        
        // Phase 2: ファイル存在確認（堅牢性向上）
        guard FileManager.default.fileExists(atPath: record.fileURL.path) else {
            print("ファイルが存在しません: \(record.fileURL.path)")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Phase 3: 並行処理で生成（YouTube方式の効率化）
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // タイムアウト機構（堅牢性向上）
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                print("サムネイル生成タイムアウト: \(record.id)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
            
            let generateAndComplete: (UIImage?) -> Void = { thumbnail in
                timeoutTimer.invalidate()
                DispatchQueue.main.async {
                    completion(thumbnail)
                }
            }
            
            switch record.type {
            case .video:
                self.generateVideoThumbnailRobust(from: record.fileURL, recordId: record.id, completion: generateAndComplete)
            case .image:
                self.generateImageThumbnailRobust(from: record.fileURL, recordId: record.id, completion: generateAndComplete)
            case .audio:
                // 音声の場合はデフォルトアイコンを使用
                generateAndComplete(nil)
            }
        }
    }
    
    // MARK: - Robust Thumbnail Generation Methods（堅牢性向上版）
    
    private func generateVideoThumbnailRobust(from url: URL, recordId: UUID, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        
        // 非同期でアセットの準備確認
        Task {
            do {
                // iOS 15+ の async/await を使用
                let duration = try await asset.load(.duration)
                guard duration.isValid && duration.seconds > 0 else {
                    print("無効な動画ファイル: \(url)")
                    completion(nil)
                    return
                }
                
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.maximumSize = thumbnailSize
                imageGenerator.requestedTimeToleranceAfter = .zero
                imageGenerator.requestedTimeToleranceBefore = .zero
                
                // 最適なフレーム選択（1秒目、または動画の1/10地点）
                let targetTime: CMTime
                if duration.seconds > 10 {
                    targetTime = CMTime(seconds: 1.0, preferredTimescale: 600)
                } else {
                    targetTime = CMTime(seconds: duration.seconds * 0.1, preferredTimescale: 600)
                }
                
                let cgImage = try await imageGenerator.image(at: targetTime).image
                let thumbnail = UIImage(cgImage: cgImage)
                let resizedImage = self.resizeImage(thumbnail, targetSize: self.thumbnailSize)
                
                // サムネイルを保存
                _ = self.saveThumbnail(resizedImage, for: recordId)
                
                completion(resizedImage)
                
            } catch {
                print("動画サムネイル生成エラー (robust): \(error)")
                // フォールバック: 従来の同期方式
                self.generateVideoThumbnailFallback(from: url, recordId: recordId, completion: completion)
            }
        }
    }
    
    private func generateVideoThumbnailFallback(from url: URL, recordId: UUID, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = thumbnailSize
        
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            let resizedImage = self.resizeImage(thumbnail, targetSize: thumbnailSize)
            
            _ = self.saveThumbnail(resizedImage, for: recordId)
            completion(resizedImage)
        } catch {
            print("動画サムネイル生成フォールバックエラー: \(error)")
            completion(nil)
        }
    }
    
    private func generateImageThumbnailRobust(from url: URL, recordId: UUID, completion: @escaping (UIImage?) -> Void) {
        // Core Graphics を直接使用（メモリ効率重視）
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("画像ソース作成失敗: \(url)")
            completion(nil)
            return
        }
        
        // 画像メタデータ確認
        guard CGImageSourceGetCount(imageSource) > 0 else {
            print("画像データなし: \(url)")
            completion(nil)
            return
        }
        
        // 効率的なサムネイル生成設定
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: max(thumbnailSize.width, thumbnailSize.height)
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            print("サムネイル作成失敗: \(url)")
            completion(nil)
            return
        }
        
        let thumbnail = UIImage(cgImage: cgImage)
        let resizedImage = self.resizeImage(thumbnail, targetSize: thumbnailSize)
        
        // サムネイルを保存
        _ = self.saveThumbnail(resizedImage, for: recordId)
        completion(resizedImage)
    }
    
    // MARK: - Generate Video Thumbnail
    private func generateVideoThumbnail(from url: URL, recordId: UUID, completion: @escaping (UIImage?) -> Void) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = thumbnailSize
        
        // 1フレーム目を取得（0秒の位置）
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            
            // リサイズして返す
            let resizedImage = self.resizeImage(thumbnail, targetSize: thumbnailSize)
            
            // サムネイルを保存
            _ = self.saveThumbnail(resizedImage, for: recordId)
            
            DispatchQueue.main.async {
                completion(resizedImage)
            }
        } catch {
            print("動画サムネイル生成エラー: \(error)")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    // MARK: - Generate Image Thumbnail
    private func generateImageThumbnail(from url: URL, recordId: UUID, completion: @escaping (UIImage?) -> Void) {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // リサイズして返す
        let resizedImage = self.resizeImage(image, targetSize: thumbnailSize)
        
        // サムネイルを保存
        _ = self.saveThumbnail(resizedImage, for: recordId)
        
        DispatchQueue.main.async {
            completion(resizedImage)
        }
    }
    
    // MARK: - Resize Image
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // アスペクト比を保ちながらフィル
        let ratio = max(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // 中央をクロップ
        if let newImage = newImage {
            return cropToSquare(image: newImage, targetSize: targetSize)
        }
        
        return image
    }
    
    // MARK: - Crop to Square
    private func cropToSquare(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let cropRect: CGRect
        
        if size.width > size.height {
            let xOffset = (size.width - size.height) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: size.height, height: size.height)
        } else {
            let yOffset = (size.height - size.width) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: size.width, height: size.width)
        }
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        let croppedImage = UIImage(cgImage: cgImage)
        
        // 最終的なサイズにリサイズ
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        croppedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return finalImage ?? croppedImage
    }
    
    // MARK: - Save Thumbnail
    func saveThumbnail(_ image: UIImage, for recordId: UUID) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails")
        
        // ディレクトリが存在しない場合は作成
        if !FileManager.default.fileExists(atPath: thumbnailsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("サムネイルディレクトリ作成エラー: \(error)")
                return nil
            }
        }
        
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(recordId.uuidString).jpg")
        
        // JPEGデータとして保存（圧縮率0.8）
        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            do {
                try jpegData.write(to: thumbnailURL)
                return thumbnailURL
            } catch {
                print("サムネイル保存エラー: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    // MARK: - Load Saved Thumbnail
    func loadSavedThumbnail(for recordId: UUID) -> UIImage? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(recordId.uuidString).jpg")
        
        // ファイルが存在するか確認
        guard FileManager.default.fileExists(atPath: thumbnailURL.path),
              let imageData = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }
    
    // MARK: - Delete Thumbnail
    func deleteThumbnail(for recordId: UUID) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails")
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(recordId.uuidString).jpg")
        
        // ファイルが存在する場合は削除
        if FileManager.default.fileExists(atPath: thumbnailURL.path) {
            try? FileManager.default.removeItem(at: thumbnailURL)
        }
    }
}