import Foundation
import AVFoundation
import UIKit

// MARK: - Video Editor Service
@MainActor
class VideoEditorService: ObservableObject {
    // MARK: - Properties
    private let asset: AVAsset
    private var exportSession: AVAssetExportSession?
    
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0
    @Published var error: VideoEditorError?
    
    // MARK: - Initialization
    init(videoURL: URL) throws {
        self.asset = AVAsset(url: videoURL)
        
        // アセットが有効か確認
        guard asset.duration.seconds > 0 else {
            throw VideoEditorError.assetNotFound
        }
    }
    
    // MARK: - Video Information
    var videoDuration: CMTime {
        return asset.duration
    }
    
    var videoSize: CGSize {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return .zero
        }
        
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    // MARK: - Export Methods
    
    /// 編集した動画をエクスポート
    func exportEditedVideo(
        with parameters: VideoEditParameters,
        outputURL: URL,
        quality: VideoExportQuality = .high
    ) async throws -> URL {
        
        isProcessing = true
        processingProgress = 0
        defer { isProcessing = false }
        
        // 既存のファイルを削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Compositionを作成
        let composition = AVMutableComposition()
        
        // ビデオトラックを追加
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoEditorError.assetNotFound
        }
        
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        // オーディオトラックを追加
        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
            
            try compositionAudioTrack?.insertTimeRange(
                parameters.timeRange,
                of: audioTrack,
                at: .zero
            )
        }
        
        // ビデオトラックに時間範囲を設定（トリミング）
        try compositionVideoTrack?.insertTimeRange(
            parameters.timeRange,
            of: videoTrack,
            at: .zero
        )
        
        // ビデオコンポジションを作成（クロッピングとスピード調整用）
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        // レンダーサイズを設定
        let renderSize: CGSize
        if let cropRect = parameters.cropRect {
            renderSize = cropRect.size
        } else {
            renderSize = videoSize
        }
        videoComposition.renderSize = renderSize
        
        // インストラクションを作成
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack!)
        
        // クロップ変換を適用
        if let cropRect = parameters.cropRect {
            let transform = CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y)
            layerInstruction.setTransform(transform, at: .zero)
        } else {
            layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
        }
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // エクスポートセッションを作成
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: quality.avPresetName
        ) else {
            throw VideoEditorError.exportFailed("エクスポートセッションの作成に失敗しました")
        }
        
        self.exportSession = exportSession
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        // プログレスの監視
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                self.processingProgress = exportSession.progress
            }
        }
        
        // エクスポート実行
        await exportSession.export()
        progressTimer.invalidate()
        
        // エラーチェック
        switch exportSession.status {
        case .completed:
            processingProgress = 1.0
            return outputURL
            
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "不明なエラー"
            throw VideoEditorError.exportFailed(errorMessage)
            
        case .cancelled:
            throw VideoEditorError.processingCancelled
            
        default:
            throw VideoEditorError.exportFailed("エクスポートが予期せず終了しました")
        }
    }
    
    /// サムネイルを生成
    func generateThumbnail(at time: CMTime) async throws -> UIImage {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 320, height: 320)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            throw VideoEditorError.exportFailed("サムネイル生成に失敗しました: \(error.localizedDescription)")
        }
    }
    
    /// フレーム画像を取得
    func getFrame(at time: CMTime) async throws -> UIImage {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            throw VideoEditorError.exportFailed("フレーム取得に失敗しました: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cancel Export
    func cancelExport() {
        exportSession?.cancelExport()
    }
}

// MARK: - Video Export Quality
enum VideoExportQuality {
    case low
    case medium
    case high
    case highest
    
    var avPresetName: String {
        switch self {
        case .low:
            return AVAssetExportPresetLowQuality
        case .medium:
            return AVAssetExportPresetMediumQuality
        case .high:
            return AVAssetExportPresetHighestQuality
        case .highest:
            return AVAssetExportPresetPassthrough
        }
    }
}