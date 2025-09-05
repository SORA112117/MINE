import UIKit
import AVFoundation

// MARK: - Ultra Crop View
/// HTMLアルゴリズムベースの高精度単一ビュークロッピングシステム
/// 参考: 高機能画像クロッピングツールのアルゴリズム
class UltraCropView: UIView {
    
    // MARK: - Types
    
    enum CropState {
        case idle           // 待機状態
        case dragging       // 新規領域作成ドラッグ
        case resizing       // ハンドルリサイズ
        case moving         // 領域移動ドラッグ
    }
    
    enum HandleType: CaseIterable {
        case topLeft, topCenter, topRight
        case middleLeft, middleRight
        case bottomLeft, bottomCenter, bottomRight
        
        var isCorner: Bool {
            switch self {
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                return true
            default:
                return false
            }
        }
        
        var cursor: String {
            switch self {
            case .topLeft, .bottomRight: return "nw-resize"
            case .topRight, .bottomLeft: return "ne-resize"
            case .topCenter, .bottomCenter: return "n-resize"
            case .middleLeft, .middleRight: return "w-resize"
            }
        }
    }
    
    // MARK: - Properties
    
    // コールバック
    var onCropChanged: ((CGRect) -> Void)?
    
    // 表示要素
    private let playerLayer: AVPlayerLayer
    private let videoSize: CGSize
    
    // 状態管理
    private var currentState: CropState = .idle
    private var hasValidCropArea: Bool = false
    private var maintainAspectRatio: Bool = false
    private var aspectRatio: CGFloat = 1.0
    
    // 座標系
    private var videoDisplayRect: CGRect = .zero
    private var cropRect: CGRect = .zero
    
    // ドラッグ状態
    private var activeHandle: HandleType?
    private var touchStartPoint: CGPoint = .zero
    private var startFrame: CGRect = .zero
    private var moveOffset: CGPoint = .zero
    
    // 制約
    private let minDragDistance: CGFloat = 5
    private let minCropSize: CGFloat = 20
    private let handleSize: CGFloat = 44 // タッチ領域サイズ
    private let handleVisualSize: CGFloat = 12 // 見た目サイズ
    
    // MARK: - Initialization
    
    init(player: AVPlayer, videoSize: CGSize) {
        self.playerLayer = AVPlayerLayer(player: player)
        self.videoSize = videoSize
        
        super.init(frame: .zero)
        setupPlayerLayer()
        setupGestures()
        backgroundColor = UIColor.black
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
    
    private func setupGestures() {
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateVideoDisplayRect()
        updatePlayerLayerFrame()
        
        // 初回レイアウト時にデフォルトクロップ領域を設定
        if !hasValidCropArea && !videoDisplayRect.isEmpty {
            createDefaultCropRect()
        }
    }
    
    // MARK: - Public Methods
    
    func updateCropSettings(aspectRatio: CropAspectRatio, showOverlay: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if showOverlay && !self.videoDisplayRect.isEmpty {
                self.applyCropAspectRatio(aspectRatio)
                self.isHidden = false
            } else {
                self.isHidden = !showOverlay
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
    
    private func updatePlayerLayerFrame() {
        playerLayer.frame = bounds
    }
    
    /// デフォルトクロップ領域作成
    private func createDefaultCropRect() {
        guard !videoDisplayRect.isEmpty else { return }
        
        // 動画表示領域全体をデフォルトとして設定
        let margin: CGFloat = 20
        cropRect = videoDisplayRect.insetBy(dx: margin, dy: margin)
        hasValidCropArea = true
        
        setNeedsDisplay()
        notifyCropChange()
    }
    
    /// アスペクト比適用（サイズ保持重視）
    private func applyCropAspectRatio(_ aspectRatio: CropAspectRatio) {
        guard hasValidCropArea else {
            createDefaultCropRect(for: aspectRatio)
            return
        }
        
        let targetRatio: CGFloat
        switch aspectRatio {
        case .free:
            maintainAspectRatio = false
            return
        case .square:
            targetRatio = 1.0
        case .portrait:
            targetRatio = 9.0 / 16.0
        case .landscape:
            targetRatio = 16.0 / 9.0
        }
        
        maintainAspectRatio = true
        self.aspectRatio = targetRatio
        
        // 現在のクロップ領域の中心とサイズを基準に調整
        let currentCenter = CGPoint(x: cropRect.midX, y: cropRect.midY)
        let currentSize = cropRect.size
        
        // アスペクト比に合わせた新しいサイズを計算
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        let currentRatio = currentSize.width / currentSize.height
        if currentRatio > targetRatio {
            // 現在が横長すぎる場合は高さを基準に
            newHeight = currentSize.height
            newWidth = newHeight * targetRatio
        } else {
            // 現在が縦長すぎる場合は幅を基準に
            newWidth = currentSize.width
            newHeight = newWidth / targetRatio
        }
        
        // 動画表示領域内に制限
        let maxWidth = videoDisplayRect.width
        let maxHeight = videoDisplayRect.height
        
        if newWidth > maxWidth {
            newWidth = maxWidth
            newHeight = newWidth / targetRatio
        }
        if newHeight > maxHeight {
            newHeight = maxHeight
            newWidth = newHeight * targetRatio
        }
        
        // 新しいクロップ領域を設定
        cropRect = CGRect(
            x: currentCenter.x - newWidth / 2,
            y: currentCenter.y - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
        
        // 境界内に制限
        cropRect = constrainCropRect(cropRect, to: videoDisplayRect)
        
        setNeedsDisplay()
        notifyCropChange()
    }
    
    private func createDefaultCropRect(for aspectRatio: CropAspectRatio) {
        guard !videoDisplayRect.isEmpty else { return }
        
        let targetRatio: CGFloat
        switch aspectRatio {
        case .free:
            createDefaultCropRect()
            return
        case .square:
            targetRatio = 1.0
        case .portrait:
            targetRatio = 9.0 / 16.0
        case .landscape:
            targetRatio = 16.0 / 9.0
        }
        
        let margin: CGFloat = 20
        let availableRect = videoDisplayRect.insetBy(dx: margin, dy: margin)
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
        
        cropRect = CGRect(x: x, y: y, width: width, height: height)
        hasValidCropArea = true
        maintainAspectRatio = true
        self.aspectRatio = targetRatio
        
        setNeedsDisplay()
        notifyCropChange()
    }
    
    // MARK: - Touch Handling (核心アルゴリズム)
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        touchStartPoint = point
        currentState = determineTouchAction(at: point)
        
        switch currentState {
        case .resizing:
            startFrame = cropRect
            
        case .moving:
            moveOffset = CGPoint(
                x: point.x - cropRect.midX,
                y: point.y - cropRect.midY
            )
            
        case .dragging:
            // 新規作成開始
            cropRect = CGRect(origin: point, size: .zero)
            hasValidCropArea = false
            
        case .idle:
            break
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        switch currentState {
        case .resizing:
            handleResize(to: point)
            
        case .moving:
            handleMove(to: point)
            
        case .dragging:
            handleDrag(to: point)
            
        case .idle:
            break
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if currentState == .dragging {
            // ドラッグ終了時の検証
            let dragDistance = sqrt(
                pow(cropRect.width, 2) + pow(cropRect.height, 2)
            )
            
            if dragDistance >= minDragDistance {
                hasValidCropArea = true
                cropRect = normalizeCropRect(cropRect)
                cropRect = constrainCropRect(cropRect, to: videoDisplayRect)
            } else {
                // ドラッグ距離が不十分な場合は既存状態を維持
                if !hasValidCropArea {
                    createDefaultCropRect()
                }
            }
        }
        
        currentState = .idle
        activeHandle = nil
        
        setNeedsDisplay()
        notifyCropChange()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        touchesEnded(touches, with: event)
    }
    
    // MARK: - Touch Action Determination (HTMLアルゴリズム移植)
    
    private func determineTouchAction(at point: CGPoint) -> CropState {
        // Step 1: ハンドル範囲チェック（最優先）
        if let handle = detectHandleAt(point) {
            activeHandle = handle
            return .resizing
        }
        
        // Step 2: 有効なクロップ領域が存在するかチェック
        guard hasValidCropArea else {
            return .dragging
        }
        
        // Step 3: クロップ領域内かつハンドル近辺でないかチェック
        if cropRect.contains(point) && !isNearAnyHandle(point) {
            return .moving
        }
        
        // Step 4: 領域外は新規作成
        return .dragging
    }
    
    private func detectHandleAt(_ point: CGPoint) -> HandleType? {
        guard hasValidCropArea else { return nil }
        
        let handles = calculateHandlePositions()
        
        for (type, position) in handles {
            let handleRect = CGRect(
                x: position.x - handleSize / 2,
                y: position.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            
            if handleRect.contains(point) {
                return type
            }
        }
        
        return nil
    }
    
    private func isNearAnyHandle(_ point: CGPoint) -> Bool {
        let handles = calculateHandlePositions()
        let exclusionRadius: CGFloat = handleSize / 2
        
        for (_, position) in handles {
            let distance = sqrt(
                pow(point.x - position.x, 2) + pow(point.y - position.y, 2)
            )
            if distance < exclusionRadius {
                return true
            }
        }
        
        return false
    }
    
    private func calculateHandlePositions() -> [HandleType: CGPoint] {
        return [
            .topLeft: CGPoint(x: cropRect.minX, y: cropRect.minY),
            .topCenter: CGPoint(x: cropRect.midX, y: cropRect.minY),
            .topRight: CGPoint(x: cropRect.maxX, y: cropRect.minY),
            .middleLeft: CGPoint(x: cropRect.minX, y: cropRect.midY),
            .middleRight: CGPoint(x: cropRect.maxX, y: cropRect.midY),
            .bottomLeft: CGPoint(x: cropRect.minX, y: cropRect.maxY),
            .bottomCenter: CGPoint(x: cropRect.midX, y: cropRect.maxY),
            .bottomRight: CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        ]
    }
    
    // MARK: - Gesture Handlers
    
    private func handleResize(to point: CGPoint) {
        guard let handle = activeHandle else { return }
        
        let translation = CGPoint(
            x: point.x - touchStartPoint.x,
            y: point.y - touchStartPoint.y
        )
        
        var newFrame = startFrame
        
        // HTMLアルゴリズムベースのリサイズ処理
        switch handle {
        case .topLeft:
            newFrame.origin.x += translation.x
            newFrame.origin.y += translation.y
            newFrame.size.width -= translation.x
            newFrame.size.height -= translation.y
            
        case .topCenter:
            newFrame.origin.y += translation.y
            newFrame.size.height -= translation.y
            
        case .topRight:
            newFrame.origin.y += translation.y
            newFrame.size.width += translation.x
            newFrame.size.height -= translation.y
            
        case .middleLeft:
            newFrame.origin.x += translation.x
            newFrame.size.width -= translation.x
            
        case .middleRight:
            newFrame.size.width += translation.x
            
        case .bottomLeft:
            newFrame.origin.x += translation.x
            newFrame.size.width -= translation.x
            newFrame.size.height += translation.y
            
        case .bottomCenter:
            newFrame.size.height += translation.y
            
        case .bottomRight:
            newFrame.size.width += translation.x
            newFrame.size.height += translation.y
        }
        
        // アスペクト比維持処理
        if maintainAspectRatio {
            newFrame = enforceAspectRatio(newFrame, handle: handle)
        }
        
        // 境界制限適用
        cropRect = constrainCropRect(newFrame, to: videoDisplayRect)
        
        setNeedsDisplay()
    }
    
    private func handleMove(to point: CGPoint) {
        let newCenterX = point.x - moveOffset.x
        let newCenterY = point.y - moveOffset.y
        
        let cropWidth = cropRect.width
        let cropHeight = cropRect.height
        
        var newFrame = CGRect(
            x: newCenterX - cropWidth / 2,
            y: newCenterY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        )
        
        // 厳格な境界制限（HTMLアルゴリズム）
        if newFrame.minX < videoDisplayRect.minX {
            newFrame.origin.x = videoDisplayRect.minX
        }
        if newFrame.minY < videoDisplayRect.minY {
            newFrame.origin.y = videoDisplayRect.minY
        }
        if newFrame.maxX > videoDisplayRect.maxX {
            newFrame.origin.x = videoDisplayRect.maxX - cropWidth
        }
        if newFrame.maxY > videoDisplayRect.maxY {
            newFrame.origin.y = videoDisplayRect.maxY - cropHeight
        }
        
        cropRect = newFrame
        setNeedsDisplay()
    }
    
    private func handleDrag(to point: CGPoint) {
        let minX = min(touchStartPoint.x, point.x)
        let minY = min(touchStartPoint.y, point.y)
        let maxX = max(touchStartPoint.x, point.x)
        let maxY = max(touchStartPoint.y, point.y)
        
        cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        setNeedsDisplay()
    }
    
    // MARK: - Constraint Methods
    
    private func constrainCropRect(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var constrained = rect
        
        // サイズ制限
        constrained.size.width = max(minCropSize, min(constrained.size.width, bounds.width))
        constrained.size.height = max(minCropSize, min(constrained.size.height, bounds.height))
        
        // 位置制限
        if constrained.origin.x < bounds.minX {
            constrained.origin.x = bounds.minX
        }
        if constrained.origin.y < bounds.minY {
            constrained.origin.y = bounds.minY
        }
        if constrained.maxX > bounds.maxX {
            constrained.origin.x = bounds.maxX - constrained.width
        }
        if constrained.maxY > bounds.maxY {
            constrained.origin.y = bounds.maxY - constrained.height
        }
        
        return constrained
    }
    
    private func normalizeCropRect(_ rect: CGRect) -> CGRect {
        let minX = min(rect.origin.x, rect.origin.x + rect.width)
        let minY = min(rect.origin.y, rect.origin.y + rect.height)
        let maxX = max(rect.origin.x, rect.origin.x + rect.width)
        let maxY = max(rect.origin.y, rect.origin.y + rect.height)
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func enforceAspectRatio(_ frame: CGRect, handle: HandleType) -> CGRect {
        var constrainedFrame = frame
        let currentRatio = frame.width / frame.height
        
        if handle.isCorner {
            // コーナーハンドル: アスペクト比を維持しながらサイズ調整
            if currentRatio > aspectRatio {
                constrainedFrame.size.height = frame.width / aspectRatio
            } else {
                constrainedFrame.size.width = frame.height * aspectRatio
            }
            
            // 位置調整
            switch handle {
            case .topLeft:
                constrainedFrame.origin.x = frame.maxX - constrainedFrame.width
                constrainedFrame.origin.y = frame.maxY - constrainedFrame.height
            case .topRight:
                constrainedFrame.origin.y = frame.maxY - constrainedFrame.height
            case .bottomLeft:
                constrainedFrame.origin.x = frame.maxX - constrainedFrame.width
            case .bottomRight:
                break // 原点はそのまま
            default:
                break
            }
        }
        
        return constrainedFrame
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext(),
              hasValidCropArea,
              !videoDisplayRect.isEmpty else { return }
        
        // 全画面マスク
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
        
        // 動画表示領域クリア
        context.setBlendMode(.clear)
        context.fill(videoDisplayRect)
        context.setBlendMode(.normal)
        
        // クロップ領域外マスク
        let maskPath = UIBezierPath(rect: videoDisplayRect)
        let cropPath = UIBezierPath(rect: cropRect)
        maskPath.append(cropPath.reversing())
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        maskPath.fill()
        
        // クロップ境界線
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(cropRect)
        
        // グリッド線
        drawGrid(in: context)
        
        // ハンドル描画
        drawHandles(in: context)
    }
    
    private func drawGrid(in context: CGContext) {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        
        let thirdWidth = cropRect.width / 3
        let thirdHeight = cropRect.height / 3
        
        // 縦線
        for i in 1..<3 {
            let x = cropRect.origin.x + thirdWidth * CGFloat(i)
            context.move(to: CGPoint(x: x, y: cropRect.origin.y))
            context.addLine(to: CGPoint(x: x, y: cropRect.maxY))
        }
        
        // 横線
        for i in 1..<3 {
            let y = cropRect.origin.y + thirdHeight * CGFloat(i)
            context.move(to: CGPoint(x: cropRect.origin.x, y: y))
            context.addLine(to: CGPoint(x: cropRect.maxX, y: y))
        }
        
        context.strokePath()
    }
    
    private func drawHandles(in context: CGContext) {
        let handles = calculateHandlePositions()
        
        for (_, position) in handles {
            // ハンドル背景
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(
                x: position.x - handleVisualSize / 2,
                y: position.y - handleVisualSize / 2,
                width: handleVisualSize,
                height: handleVisualSize
            ))
            
            // ハンドル境界
            context.setStrokeColor(UIColor.blue.cgColor)
            context.setLineWidth(2.0)
            context.strokeEllipse(in: CGRect(
                x: position.x - handleVisualSize / 2,
                y: position.y - handleVisualSize / 2,
                width: handleVisualSize,
                height: handleVisualSize
            ))
        }
    }
    
    // MARK: - Helpers
    
    private func notifyCropChange() {
        guard hasValidCropArea else { return }
        
        let videoCropRect = convertViewToVideoCoordinates(cropRect)
        onCropChanged?(videoCropRect)
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
        
        // 動画座標系変換
        let videoX = relativeX * videoSize.width
        let videoY = relativeY * videoSize.height
        let videoWidth = relativeWidth * videoSize.width
        let videoHeight = relativeHeight * videoSize.height
        
        return CGRect(x: videoX, y: videoY, width: videoWidth, height: videoHeight)
    }
}