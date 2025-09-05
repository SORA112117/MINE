import SwiftUI
import AVKit
import AVFoundation

// MARK: - Video Player with Crop Overlay
struct VideoPlayerCropView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    func makeUIView(context: Context) -> VideoPlayerCropUIView {
        let view = VideoPlayerCropUIView(
            player: player,
            videoSize: videoSize,
            onCropChanged: onCropChanged
        )
        return view
    }
    
    func updateUIView(_ uiView: VideoPlayerCropUIView, context: Context) {
        uiView.updateCropSettings(
            cropRect: cropRect,
            aspectRatio: aspectRatio,
            showOverlay: showCropOverlay
        )
    }
}

// MARK: - Video Player Crop UI View
class VideoPlayerCropUIView: UIView {
    
    // MARK: - Properties
    private let playerLayer: AVPlayerLayer
    private let cropOverlayView = SmartCropOverlayView()
    private let videoSize: CGSize
    private let onCropChanged: (CGRect) -> Void
    
    private var currentCropRect: CGRect = .zero
    private var currentAspectRatio: CropAspectRatio = .free
    private var showsCropOverlay: Bool = false
    
    // 動画表示領域の計算結果をキャッシュ
    private var videoDisplayRect: CGRect = .zero
    
    // MARK: - Initialization
    init(player: AVPlayer, videoSize: CGSize, onCropChanged: @escaping (CGRect) -> Void) {
        self.playerLayer = AVPlayerLayer(player: player)
        self.videoSize = videoSize
        self.onCropChanged = onCropChanged
        
        super.init(frame: .zero)
        setupPlayerLayer()
        setupCropOverlay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupPlayerLayer() {
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(playerLayer)
    }
    
    private func setupCropOverlay() {
        addSubview(cropOverlayView)
        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cropOverlayView.topAnchor.constraint(equalTo: topAnchor),
            cropOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cropOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cropOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        cropOverlayView.onCropChanged = { [weak self] rect in
            self?.currentCropRect = rect
            self?.onCropChanged(rect)
        }
        
        cropOverlayView.isHidden = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        updateVideoDisplayRect()
        updateCropOverlay()
    }
    
    // MARK: - Public Methods
    func updateCropSettings(cropRect: CGRect, aspectRatio: CropAspectRatio, showOverlay: Bool) {
        // メインスレッドで安全に実行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentCropRect = cropRect
            self.currentAspectRatio = aspectRatio
            self.showsCropOverlay = showOverlay
            
            self.cropOverlayView.isHidden = !showOverlay
            
            if showOverlay {
                self.updateVideoDisplayRect()
                
                // 有効な動画表示領域がある場合のみオーバーレイを更新
                if !self.videoDisplayRect.isEmpty {
                    self.cropOverlayView.updateSettings(
                        videoDisplayRect: self.videoDisplayRect,
                        videoSize: self.videoSize,
                        aspectRatio: aspectRatio,
                        initialCropRect: cropRect
                    )
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 動画の実際の表示領域を計算（アスペクトフィット）
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
    
    private func updateCropOverlay() {
        guard showsCropOverlay && !videoDisplayRect.isEmpty else { return }
        
        cropOverlayView.updateSettings(
            videoDisplayRect: videoDisplayRect,
            videoSize: videoSize,
            aspectRatio: currentAspectRatio,
            initialCropRect: currentCropRect
        )
    }
}

// MARK: - Smart Crop Overlay View
class SmartCropOverlayView: UIView {
    
    // MARK: - Properties
    var onCropChanged: ((CGRect) -> Void)?
    
    private var videoDisplayRect: CGRect = .zero
    private var videoSize: CGSize = .zero
    private var aspectRatio: CropAspectRatio = .free
    private var cropRect: CGRect = .zero // 動画座標系でのクロップ矩形
    
    // ジェスチャー関連
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    
    // クロップフレーム（ビュー座標系）
    private var viewCropFrame: CGRect = .zero
    
    // 変換パラメータ
    private var currentScale: CGFloat = 1.0
    private var currentTranslation: CGPoint = .zero
    private var lastScale: CGFloat = 1.0
    private var lastTranslation: CGPoint = .zero
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
        backgroundColor = UIColor.clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
        backgroundColor = UIColor.clear
    }
    
    // MARK: - Setup
    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        
        addGestureRecognizer(panGesture)
        addGestureRecognizer(pinchGesture)
        
        // 同時ジェスチャーを有効化
        panGesture.delegate = self
        pinchGesture.delegate = self
    }
    
    // MARK: - Public Methods
    func updateSettings(videoDisplayRect: CGRect, videoSize: CGSize, aspectRatio: CropAspectRatio, initialCropRect: CGRect) {
        // 安全性チェック
        guard !videoDisplayRect.isEmpty && 
              videoSize.width > 0 && 
              videoSize.height > 0 else {
            print("Warning: Invalid parameters for crop overlay update")
            return
        }
        
        // メインスレッドで安全に更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.videoDisplayRect = videoDisplayRect
            self.videoSize = videoSize
            self.aspectRatio = aspectRatio
            self.cropRect = initialCropRect
            
            // 初期クロップフレームを設定
            self.setupInitialCropFrame()
            self.setNeedsDisplay()
        }
    }
    
    // MARK: - Private Methods
    
    /// 初期クロップフレームの設定
    private func setupInitialCropFrame() {
        guard !videoDisplayRect.isEmpty && videoSize.width > 0 && videoSize.height > 0 else { return }
        
        // アスペクト比に基づく初期フレーム計算
        let initialFrame = calculateInitialCropFrame()
        viewCropFrame = initialFrame
        
        // 動画座標系に変換してコールバック
        let videoCropRect = convertViewToVideoCoordinates(viewCropFrame)
        cropRect = videoCropRect
        onCropChanged?(videoCropRect)
        
        // 変換パラメータをリセット
        currentScale = 1.0
        currentTranslation = .zero
        lastScale = 1.0
        lastTranslation = .zero
    }
    
    /// アスペクト比に基づく初期クロップフレーム計算
    private func calculateInitialCropFrame() -> CGRect {
        let margin: CGFloat = 20
        let availableRect = videoDisplayRect.insetBy(dx: margin, dy: margin)
        
        switch aspectRatio {
        case .free:
            // フリー - 動画表示領域の80%
            return availableRect
            
        case .square:
            // 正方形 - 利用可能領域に収まる最大正方形
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
    
    /// 指定アスペクト比でのフレーム計算
    private func calculateAspectRatioFrame(targetRatio: CGFloat, in availableRect: CGRect) -> CGRect {
        let availableRatio = availableRect.width / availableRect.height
        
        var width: CGFloat
        var height: CGFloat
        
        if targetRatio > availableRatio {
            // 横長のアスペクト比 - 幅基準
            width = availableRect.width
            height = width / targetRatio
        } else {
            // 縦長のアスペクト比 - 高さ基準  
            height = availableRect.height
            width = height * targetRatio
        }
        
        let x = videoDisplayRect.midX - width / 2
        let y = videoDisplayRect.midY - height / 2
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began:
            lastTranslation = currentTranslation
            
        case .changed:
            let newTranslation = CGPoint(
                x: lastTranslation.x + translation.x,
                y: lastTranslation.y + translation.y
            )
            
            // 動画表示領域内に制限
            currentTranslation = constrainTranslation(newTranslation)
            updateCropFromTransform()
            setNeedsDisplay()
            
        case .ended, .cancelled:
            lastTranslation = currentTranslation
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let scale = gesture.scale
        
        switch gesture.state {
        case .began:
            lastScale = currentScale
            
        case .changed:
            let newScale = lastScale * scale
            // スケール制限（動画表示領域に収まる範囲）
            currentScale = constrainScale(newScale)
            updateCropFromTransform()
            setNeedsDisplay()
            
        case .ended, .cancelled:
            lastScale = currentScale
            
        default:
            break
        }
    }
    
    // MARK: - Transform Constraints
    
    /// スケールを動画表示領域内に制限
    private func constrainScale(_ scale: CGFloat) -> CGFloat {
        let minScale: CGFloat = 0.1 // 最小10%
        let maxScale: CGFloat = 5.0 // 最大500%
        return max(minScale, min(maxScale, scale))
    }
    
    /// 平行移動を動画表示領域内に制限
    private func constrainTranslation(_ translation: CGPoint) -> CGPoint {
        let baseFrame = calculateInitialCropFrame()
        let scaledSize = CGSize(
            width: baseFrame.width / currentScale,
            height: baseFrame.height / currentScale
        )
        
        // 制限範囲計算
        let minX = videoDisplayRect.minX + scaledSize.width / 2 - baseFrame.midX
        let maxX = videoDisplayRect.maxX - scaledSize.width / 2 - baseFrame.midX
        let minY = videoDisplayRect.minY + scaledSize.height / 2 - baseFrame.midY
        let maxY = videoDisplayRect.maxY - scaledSize.height / 2 - baseFrame.midY
        
        return CGPoint(
            x: max(minX, min(maxX, translation.x)),
            y: max(minY, min(maxY, translation.y))
        )
    }
    
    // MARK: - Transform Update
    private func updateCropFromTransform() {
        let baseFrame = calculateInitialCropFrame()
        
        // 変換後のフレーム計算
        let scaledWidth = baseFrame.width / currentScale
        let scaledHeight = baseFrame.height / currentScale
        
        let centerX = baseFrame.midX + currentTranslation.x
        let centerY = baseFrame.midY + currentTranslation.y
        
        viewCropFrame = CGRect(
            x: centerX - scaledWidth / 2,
            y: centerY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )
        
        // 動画座標系に変換してコールバック
        let videoCropRect = convertViewToVideoCoordinates(viewCropFrame)
        cropRect = videoCropRect
        onCropChanged?(videoCropRect)
    }
    
    /// ビュー座標から動画座標への変換
    private func convertViewToVideoCoordinates(_ viewRect: CGRect) -> CGRect {
        guard !videoDisplayRect.isEmpty && videoSize.width > 0 && videoSize.height > 0 else { 
            return .zero 
        }
        
        // ビュー座標での動画表示領域を基準とした相対座標
        let relativeX = (viewRect.origin.x - videoDisplayRect.origin.x) / videoDisplayRect.width
        let relativeY = (viewRect.origin.y - videoDisplayRect.origin.y) / videoDisplayRect.height
        let relativeWidth = viewRect.width / videoDisplayRect.width
        let relativeHeight = viewRect.height / videoDisplayRect.height
        
        // 動画座標系に変換
        let videoX = relativeX * videoSize.width
        let videoY = relativeY * videoSize.height
        let videoWidth = relativeWidth * videoSize.width
        let videoHeight = relativeHeight * videoSize.height
        
        // 動画境界内に制限
        let clampedX = max(0, min(videoX, videoSize.width - videoWidth))
        let clampedY = max(0, min(videoY, videoSize.height - videoHeight))
        let clampedWidth = min(videoWidth, videoSize.width - clampedX)
        let clampedHeight = min(videoHeight, videoSize.height - clampedY)
        
        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext(),
              !videoDisplayRect.isEmpty,
              !viewCropFrame.isEmpty else { return }
        
        // 全体を暗くする
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
        
        // 動画表示領域をクリアして表示
        context.setBlendMode(.clear)
        context.fill(videoDisplayRect)
        context.setBlendMode(.normal)
        
        // 動画表示領域に軽い境界線（デバッグ用）
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(0.5)
        context.stroke(videoDisplayRect)
        
        // クロップ領域外（動画表示領域内）を暗くする
        let cropMaskPath = UIBezierPath(rect: videoDisplayRect)
        let cropFramePath = UIBezierPath(rect: viewCropFrame)
        cropMaskPath.append(cropFramePath.reversing())
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        cropMaskPath.fill()
        
        // メインのクロップ枠を描画
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(viewCropFrame)
        
        // グリッドライン
        drawGridLines(in: context, frame: viewCropFrame)
        
        // iOS風のコーナーハンドル
        drawModernCornerHandles(in: context, frame: viewCropFrame)
        
        // 指示テキスト
        drawInstructions(in: context)
    }
    
    private func drawGridLines(in context: CGContext, frame: CGRect) {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(0.5)
        
        let thirdWidth = frame.width / 3
        let thirdHeight = frame.height / 3
        
        // 縦線
        for i in 1..<3 {
            let x = frame.origin.x + thirdWidth * CGFloat(i)
            context.move(to: CGPoint(x: x, y: frame.origin.y))
            context.addLine(to: CGPoint(x: x, y: frame.maxY))
        }
        
        // 横線
        for i in 1..<3 {
            let y = frame.origin.y + thirdHeight * CGFloat(i)
            context.move(to: CGPoint(x: frame.origin.x, y: y))
            context.addLine(to: CGPoint(x: frame.maxX, y: y))
        }
        
        context.strokePath()
    }
    
    private func drawModernCornerHandles(in context: CGContext, frame: CGRect) {
        let handleLength: CGFloat = 20
        let handleThickness: CGFloat = 3
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(handleThickness)
        context.setLineCap(.round)
        
        let corners = [
            (frame.origin, [CGPoint(x: 0, y: handleLength), CGPoint(x: handleLength, y: 0)]),
            (CGPoint(x: frame.maxX, y: frame.origin.y), [CGPoint(x: -handleLength, y: 0), CGPoint(x: 0, y: handleLength)]),
            (CGPoint(x: frame.origin.x, y: frame.maxY), [CGPoint(x: 0, y: -handleLength), CGPoint(x: handleLength, y: 0)]),
            (CGPoint(x: frame.maxX, y: frame.maxY), [CGPoint(x: -handleLength, y: 0), CGPoint(x: 0, y: -handleLength)])
        ]
        
        for (corner, offsets) in corners {
            for offset in offsets {
                context.move(to: corner)
                context.addLine(to: CGPoint(x: corner.x + offset.x, y: corner.y + offset.y))
                context.strokePath()
            }
        }
    }
    
    private func drawInstructions(in context: CGContext) {
        let instructionText = "ピンチしてズーム、ドラッグして移動"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]
        
        let attributedString = NSAttributedString(string: instructionText, attributes: attributes)
        let textSize = attributedString.size()
        
        // 動画表示領域の下部に配置
        let textRect = CGRect(
            x: videoDisplayRect.midX - textSize.width / 2,
            y: videoDisplayRect.maxY + 10,
            width: textSize.width,
            height: textSize.height
        )
        
        // 背景
        let backgroundRect = textRect.insetBy(dx: -8, dy: -4)
        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 8)
        backgroundPath.fill()
        
        attributedString.draw(in: textRect)
    }
}

// MARK: - Gesture Recognizer Delegate
extension SmartCropOverlayView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // パンとピンチの同時操作を許可
    }
}