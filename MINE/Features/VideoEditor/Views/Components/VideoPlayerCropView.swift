import SwiftUI
import AVKit
import AVFoundation

// MARK: - Video Player with Professional Crop System
struct VideoPlayerCropView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    func makeUIView(context: Context) -> UIView {
        // 新しいProCropSystemを使用
        let containerView = ProCropContainerUIView(
            player: player,
            videoSize: videoSize,
            onCropChanged: onCropChanged
        )
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let containerView = uiView as? ProCropContainerUIView {
            containerView.updateCropSettings(
                cropRect: cropRect,
                aspectRatio: aspectRatio,
                showOverlay: showCropOverlay
            )
        }
    }
}

// MARK: - Legacy Support (Deprecated)
/// 以前のSmartCropOverlayViewは完全にProCropSystemに置き換えられました
/// このコードは後方互換性のためにのみ残されています（削除予定）

/*
// 古い実装 - 完全にProCropSystemに置き換え済み
class VideoPlayerCropUIView: UIView {
    // このクラスは使用されなくなりました
    // ProCropContainerUIViewが新しい実装です
}

class SmartCropOverlayView: UIView {
    // このクラスも使用されなくなりました
    // ProCropFrameView, ProCropContentView, ProCropOverlayViewに分割されました
}
*/