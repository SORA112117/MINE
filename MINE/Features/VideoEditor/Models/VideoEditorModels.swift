import Foundation
import AVFoundation
import CoreGraphics

// MARK: - Video Editor Models

/// 動画編集パラメータ
struct VideoEditParameters {
    var trimStartTime: CMTime = .zero
    var trimEndTime: CMTime = .zero
    var cropRect: CGRect? = nil
    var rotation: CGFloat = 0
    var playbackSpeed: Float = 1.0
    
    /// 実際の動画時間（トリミング後）
    var duration: CMTime {
        return CMTimeSubtract(trimEndTime, trimStartTime)
    }
    
    /// 時間範囲
    var timeRange: CMTimeRange {
        return CMTimeRange(start: trimStartTime, end: trimEndTime)
    }
}

/// ビデオエディターエラー
enum VideoEditorError: LocalizedError {
    case assetNotFound
    case exportFailed(String)
    case invalidTimeRange
    case cropRectOutOfBounds
    case processingCancelled
    
    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "動画ファイルが見つかりません"
        case .exportFailed(let reason):
            return "エクスポートに失敗しました: \(reason)"
        case .invalidTimeRange:
            return "無効な時間範囲が指定されました"
        case .cropRectOutOfBounds:
            return "クロップ範囲が動画の範囲を超えています"
        case .processingCancelled:
            return "処理がキャンセルされました"
        }
    }
}

/// プレビューモード
enum VideoPreviewMode {
    case original
    case edited
}

/// 編集オペレーション
enum VideoEditOperation {
    case trim
    case crop
    case rotate
    case speed
}