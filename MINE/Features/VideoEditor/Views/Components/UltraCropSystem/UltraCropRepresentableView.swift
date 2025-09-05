import SwiftUI
import AVKit
import AVFoundation

// MARK: - Ultra Crop SwiftUI Wrapper
struct UltraCropRepresentableView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    func makeUIView(context: Context) -> UltraCropView {
        let ultraCropView = UltraCropView(player: player, videoSize: videoSize)
        ultraCropView.onCropChanged = onCropChanged
        return ultraCropView
    }
    
    func updateUIView(_ uiView: UltraCropView, context: Context) {
        uiView.updateCropSettings(
            aspectRatio: aspectRatio,
            showOverlay: showCropOverlay
        )
    }
}