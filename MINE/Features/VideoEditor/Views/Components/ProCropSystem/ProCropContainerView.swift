import SwiftUI
import AVFoundation

// MARK: - ProCrop Container View
/// iPhone純正写真アプリ風の高品質クロッピングシステム
/// 全体管理と状態調整を担当
struct ProCropContainerView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    func makeUIView(context: Context) -> ProCropContainerUIView {
        let containerView = ProCropContainerUIView(
            player: player,
            videoSize: videoSize,
            onCropChanged: onCropChanged
        )
        return containerView
    }
    
    func updateUIView(_ uiView: ProCropContainerUIView, context: Context) {
        uiView.updateCropSettings(
            cropRect: cropRect,
            aspectRatio: aspectRatio,
            showOverlay: showCropOverlay
        )
    }
}

// MARK: - ProCrop Container UI View
class ProCropContainerUIView: UIView {
    
    // MARK: - Properties
    private let player: AVPlayer
    private let videoSize: CGSize
    private let onCropChanged: (CGRect) -> Void
    
    // コンポーネント
    private let contentView: ProCropContentView
    private let frameView: ProCropFrameView
    private let overlayView: ProCropOverlayView
    
    // 状態管理
    private var currentCropRect: CGRect = .zero
    private var currentAspectRatio: CropAspectRatio = .free
    private var showsCropOverlay: Bool = false
    
    // 座標系管理
    private var videoDisplayRect: CGRect = .zero
    
    // MARK: - Initialization
    init(player: AVPlayer, videoSize: CGSize, onCropChanged: @escaping (CGRect) -> Void) {
        self.player = player
        self.videoSize = videoSize
        self.onCropChanged = onCropChanged
        
        // コンポーネント初期化
        self.contentView = ProCropContentView(player: player, videoSize: videoSize)
        self.frameView = ProCropFrameView()
        self.overlayView = ProCropOverlayView()
        
        super.init(frame: .zero)
        setupComponents()
        setupCoordination()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupComponents() {
        backgroundColor = UIColor.black
        
        // 階層構造: Content -> Frame -> Overlay
        addSubview(contentView)
        addSubview(frameView)
        addSubview(overlayView)
        
        // レイアウト設定
        [contentView, frameView, overlayView].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
        
        // 初期状態では非表示
        frameView.isHidden = true
        overlayView.isHidden = true
    }
    
    private func setupCoordination() {
        // フレームビューからのハンドル操作
        frameView.onFrameChanged = { [weak self] newFrame in
            self?.handleFrameChanged(newFrame)
        }
        
        // コンテンツビューからのジェスチャー
        contentView.onContentTransformed = { [weak self] in
            self?.handleContentTransformed()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateVideoDisplayRect()
        updateAllComponents()
    }
    
    // MARK: - Public Methods
    func updateCropSettings(cropRect: CGRect, aspectRatio: CropAspectRatio, showOverlay: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentCropRect = cropRect
            self.currentAspectRatio = aspectRatio
            self.showsCropOverlay = showOverlay
            
            // コンポーネント表示状態更新
            self.frameView.isHidden = !showOverlay
            self.overlayView.isHidden = !showOverlay
            
            if showOverlay {
                self.updateVideoDisplayRect()
                self.updateAllComponents()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 動画表示領域計算（アスペクトフィット）
    private func updateVideoDisplayRect() {
        let viewBounds = bounds
        guard !viewBounds.isEmpty && videoSize.width > 0 && videoSize.height > 0 else {
            videoDisplayRect = .zero
            return
        }
        
        let videoAspectRatio = videoSize.width / videoSize.height
        let viewAspectRatio = viewBounds.width / viewBounds.height
        
        if videoAspectRatio > viewAspectRatio {
            // 動画が横長 - 横幅フィット
            let displayWidth = viewBounds.width
            let displayHeight = displayWidth / videoAspectRatio
            let x: CGFloat = 0
            let y = (viewBounds.height - displayHeight) / 2
            videoDisplayRect = CGRect(x: x, y: y, width: displayWidth, height: displayHeight)
        } else {
            // 動画が縦長 - 縦幅フィット
            let displayHeight = viewBounds.height
            let displayWidth = displayHeight * videoAspectRatio
            let x = (viewBounds.width - displayWidth) / 2
            let y: CGFloat = 0
            videoDisplayRect = CGRect(x: x, y: y, width: displayWidth, height: displayHeight)
        }
    }
    
    private func updateAllComponents() {
        guard !videoDisplayRect.isEmpty else { return }
        
        // 初期クロップフレームを計算
        let cropFrame = calculateCropFrameInView()
        
        // 各コンポーネントを更新
        contentView.updateVideoDisplayRect(videoDisplayRect)
        frameView.updateCropFrame(cropFrame, in: videoDisplayRect, aspectRatio: currentAspectRatio)
        overlayView.updateCropArea(cropFrame, videoDisplayRect: videoDisplayRect)
    }
    
    private func calculateCropFrameInView() -> CGRect {
        // アスペクト比に基づく初期フレーム計算
        let margin: CGFloat = 20
        let availableRect = videoDisplayRect.insetBy(dx: margin, dy: margin)
        
        switch currentAspectRatio {
        case .free:
            return availableRect
            
        case .square:
            let size = min(availableRect.width, availableRect.height)
            let x = videoDisplayRect.midX - size / 2
            let y = videoDisplayRect.midY - size / 2
            return CGRect(x: x, y: y, width: size, height: size)
            
        case .portrait: // 9:16
            return calculateAspectRatioFrame(targetRatio: 9.0 / 16.0, in: availableRect)
            
        case .landscape: // 16:9
            return calculateAspectRatioFrame(targetRatio: 16.0 / 9.0, in: availableRect)
        }
    }
    
    private func calculateAspectRatioFrame(targetRatio: CGFloat, in availableRect: CGRect) -> CGRect {
        let availableRatio = availableRect.width / availableRect.height
        
        var width: CGFloat
        var height: CGFloat
        
        if targetRatio > availableRatio {
            width = availableRect.width
            height = width / targetRatio
        } else {
            height = availableRect.height
            width = height * targetRatio
        }
        
        let x = videoDisplayRect.midX - width / 2
        let y = videoDisplayRect.midY - height / 2
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Event Handlers
    private func handleFrameChanged(_ newFrame: CGRect) {
        // フレームが変更された時の処理
        let videoCropRect = convertViewToVideoCoordinates(newFrame)
        currentCropRect = videoCropRect
        
        // オーバーレイを更新
        overlayView.updateCropArea(newFrame, videoDisplayRect: videoDisplayRect)
        
        // コールバック
        onCropChanged(videoCropRect)
    }
    
    private func handleContentTransformed() {
        // コンテンツが変形された時の処理
        // このケースでは、フレームは固定でコンテンツが動くので
        // 現在のフレームに基づいてクロップ領域を再計算
        let currentFrame = frameView.currentCropFrame
        handleFrameChanged(currentFrame)
    }
    
    private func convertViewToVideoCoordinates(_ viewRect: CGRect) -> CGRect {
        guard !videoDisplayRect.isEmpty && videoSize.width > 0 && videoSize.height > 0 else {
            return .zero
        }
        
        // 相対座標計算
        let relativeX = (viewRect.origin.x - videoDisplayRect.origin.x) / videoDisplayRect.width
        let relativeY = (viewRect.origin.y - videoDisplayRect.origin.y) / videoDisplayRect.height
        let relativeWidth = viewRect.width / videoDisplayRect.width
        let relativeHeight = viewRect.height / videoDisplayRect.height
        
        // 動画座標系に変換
        let videoX = relativeX * videoSize.width
        let videoY = relativeY * videoSize.height
        let videoWidth = relativeWidth * videoSize.width
        let videoHeight = relativeHeight * videoSize.height
        
        // 境界制限
        let clampedX = max(0, min(videoX, videoSize.width - videoWidth))
        let clampedY = max(0, min(videoY, videoSize.height - videoHeight))
        let clampedWidth = min(videoWidth, videoSize.width - clampedX)
        let clampedHeight = min(videoHeight, videoSize.height - clampedY)
        
        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }
}