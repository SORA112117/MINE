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
    
    // MARK: - Generate Thumbnail from Record
    func generateThumbnail(for record: Record, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            switch record.type {
            case .video:
                self.generateVideoThumbnail(from: record.fileURL, completion: completion)
            case .image:
                self.generateImageThumbnail(from: record.fileURL, completion: completion)
            case .audio:
                // 音声の場合はデフォルトアイコンを使用
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Generate Video Thumbnail
    private func generateVideoThumbnail(from url: URL, completion: @escaping (UIImage?) -> Void) {
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
    private func generateImageThumbnail(from url: URL, completion: @escaping (UIImage?) -> Void) {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // リサイズして返す
        let resizedImage = self.resizeImage(image, targetSize: thumbnailSize)
        
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
}