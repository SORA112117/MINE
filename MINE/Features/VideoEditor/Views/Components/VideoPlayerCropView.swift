import SwiftUI
import AVKit
import AVFoundation

// MARK: - Video Player with Ultra Crop System
struct VideoPlayerCropView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    func makeUIView(context: Context) -> UIView {
        // UltraCropSystem使用 - HTMLアルゴリズムベース単一ビューシステム
        let ultraCropView = UltraCropView(
            player: player,
            videoSize: videoSize
        )
        ultraCropView.onCropChanged = onCropChanged
        return ultraCropView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let ultraCropView = uiView as? UltraCropView {
            ultraCropView.updateCropSettings(
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