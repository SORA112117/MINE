import UIKit

// MARK: - ProCrop Frame View
/// クロップフレームとハンドル操作を担当
/// iPhone純正写真アプリ風の8点ハンドルシステム
class ProCropFrameView: UIView {
    
    // MARK: - Handle Types
    enum HandleType {
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
    }
    
    // MARK: - Properties
    var currentCropFrame: CGRect = .zero
    var onFrameChanged: ((CGRect) -> Void)?
    
    private var videoDisplayRect: CGRect = .zero
    private var currentAspectRatio: CropAspectRatio = .free
    private var handles: [HandleType: ProCropHandleView] = [:]
    
    // ドラッグ状態
    private var isDragging = false
    private var dragStartFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero
    private var activeHandle: HandleType?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHandles()
        backgroundColor = UIColor.clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHandles()
        backgroundColor = UIColor.clear
    }
    
    // MARK: - Setup
    private func setupHandles() {
        let handleTypes: [HandleType] = [
            .topLeft, .topCenter, .topRight,
            .middleLeft, .middleRight,
            .bottomLeft, .bottomCenter, .bottomRight
        ]
        
        for handleType in handleTypes {
            let handle = ProCropHandleView(type: handleType)
            handle.onDragBegan = { [weak self] point in
                self?.handleDragBegan(handle: handleType, at: point)
            }
            handle.onDragChanged = { [weak self] translation in
                self?.handleDragChanged(handle: handleType, translation: translation)
            }
            handle.onDragEnded = { [weak self] in
                self?.handleDragEnded(handle: handleType)
            }
            
            addSubview(handle)
            handles[handleType] = handle
        }
    }
    
    // MARK: - Public Methods
    func updateCropFrame(_ frame: CGRect, in displayRect: CGRect, aspectRatio: CropAspectRatio) {
        videoDisplayRect = displayRect
        currentAspectRatio = aspectRatio
        currentCropFrame = frame
        
        updateHandlePositions()
        setNeedsDisplay()
    }
    
    // MARK: - Private Methods
    private func updateHandlePositions() {
        let frame = currentCropFrame
        let handleSize: CGFloat = 44 // タッチ領域
        let offset = handleSize / 2
        
        // 各ハンドルの位置を計算
        let positions: [HandleType: CGPoint] = [
            .topLeft: CGPoint(x: frame.minX - offset, y: frame.minY - offset),
            .topCenter: CGPoint(x: frame.midX - offset, y: frame.minY - offset),
            .topRight: CGPoint(x: frame.maxX - offset, y: frame.minY - offset),
            .middleLeft: CGPoint(x: frame.minX - offset, y: frame.midY - offset),
            .middleRight: CGPoint(x: frame.maxX - offset, y: frame.midY - offset),
            .bottomLeft: CGPoint(x: frame.minX - offset, y: frame.maxY - offset),
            .bottomCenter: CGPoint(x: frame.midX - offset, y: frame.maxY - offset),
            .bottomRight: CGPoint(x: frame.maxX - offset, y: frame.maxY - offset)
        ]
        
        for (handleType, position) in positions {
            if let handle = handles[handleType] {
                handle.frame = CGRect(origin: position, size: CGSize(width: handleSize, height: handleSize))
            }
        }
    }
    
    // MARK: - Drag Handlers
    private func handleDragBegan(handle: HandleType, at point: CGPoint) {
        isDragging = true
        activeHandle = handle
        dragStartFrame = currentCropFrame
        dragStartPoint = point
    }
    
    private func handleDragChanged(handle: HandleType, translation: CGPoint) {
        guard isDragging, let _ = activeHandle else { return }
        
        let newFrame = calculateNewFrame(
            from: dragStartFrame,
            handle: handle,
            translation: translation
        )
        
        // 制約適用
        let constrainedFrame = constrainFrame(newFrame)
        
        if constrainedFrame != currentCropFrame {
            currentCropFrame = constrainedFrame
            updateHandlePositions()
            setNeedsDisplay()
            onFrameChanged?(currentCropFrame)
        }
    }
    
    private func handleDragEnded(handle: HandleType) {
        isDragging = false
        activeHandle = nil
        
        // 最終的な制約チェック
        let finalFrame = constrainFrame(currentCropFrame)
        if finalFrame != currentCropFrame {
            currentCropFrame = finalFrame
            updateHandlePositions()
            setNeedsDisplay()
            onFrameChanged?(currentCropFrame)
        }
    }
    
    // MARK: - Frame Calculation
    private func calculateNewFrame(from originalFrame: CGRect, handle: HandleType, translation: CGPoint) -> CGRect {
        var newFrame = originalFrame
        
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
        
        // アスペクト比制約
        if currentAspectRatio != .free {
            newFrame = enforceAspectRatio(newFrame, handle: handle)
        }
        
        return newFrame
    }
    
    private func enforceAspectRatio(_ frame: CGRect, handle: HandleType) -> CGRect {
        let targetRatio: CGFloat
        
        switch currentAspectRatio {
        case .square:
            targetRatio = 1.0
        case .portrait:
            targetRatio = 9.0 / 16.0
        case .landscape:
            targetRatio = 16.0 / 9.0
        case .free:
            return frame
        }
        
        var constrainedFrame = frame
        let currentRatio = frame.width / frame.height
        
        if handle.isCorner {
            // コーナーハンドル: アスペクト比を維持しながらサイズ調整
            if currentRatio > targetRatio {
                // 幅を基準に高さを調整
                constrainedFrame.size.height = frame.width / targetRatio
            } else {
                // 高さを基準に幅を調整
                constrainedFrame.size.width = frame.height * targetRatio
            }
            
            // 位置調整（ハンドルに応じて）
            switch handle {
            case .topLeft:
                constrainedFrame.origin.x = frame.maxX - constrainedFrame.width
                constrainedFrame.origin.y = frame.maxY - constrainedFrame.height
            case .topRight:
                constrainedFrame.origin.y = frame.maxY - constrainedFrame.height
            case .bottomLeft:
                constrainedFrame.origin.x = frame.maxX - constrainedFrame.width
            case .bottomRight:
                // 原点はそのまま
                break
            default:
                break
            }
        } else {
            // エッジハンドル: 対応する方向のみ調整
            switch handle {
            case .topCenter, .bottomCenter:
                // 高さ変更時は幅を調整
                constrainedFrame.size.width = constrainedFrame.height * targetRatio
                constrainedFrame.origin.x = frame.midX - constrainedFrame.width / 2
                
            case .middleLeft, .middleRight:
                // 幅変更時は高さを調整
                constrainedFrame.size.height = constrainedFrame.width / targetRatio
                constrainedFrame.origin.y = frame.midY - constrainedFrame.height / 2
                
            default:
                break
            }
        }
        
        return constrainedFrame
    }
    
    private func constrainFrame(_ frame: CGRect) -> CGRect {
        guard !videoDisplayRect.isEmpty else { return frame }
        
        let minSize: CGFloat = 50 // 最小サイズ
        var constrainedFrame = frame
        
        // サイズ制限
        constrainedFrame.size.width = max(minSize, constrainedFrame.size.width)
        constrainedFrame.size.height = max(minSize, constrainedFrame.size.height)
        
        // 位置制限（動画表示領域内）
        constrainedFrame.origin.x = max(videoDisplayRect.minX, constrainedFrame.origin.x)
        constrainedFrame.origin.y = max(videoDisplayRect.minY, constrainedFrame.origin.y)
        
        // 右下境界チェック
        if constrainedFrame.maxX > videoDisplayRect.maxX {
            constrainedFrame.origin.x = videoDisplayRect.maxX - constrainedFrame.width
        }
        if constrainedFrame.maxY > videoDisplayRect.maxY {
            constrainedFrame.origin.y = videoDisplayRect.maxY - constrainedFrame.height
        }
        
        // 最終サイズ調整（境界に収まるように）
        if constrainedFrame.maxX > videoDisplayRect.maxX {
            constrainedFrame.size.width = videoDisplayRect.maxX - constrainedFrame.origin.x
        }
        if constrainedFrame.maxY > videoDisplayRect.maxY {
            constrainedFrame.size.height = videoDisplayRect.maxY - constrainedFrame.origin.y
        }
        
        return constrainedFrame
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext(),
              !currentCropFrame.isEmpty else { return }
        
        // クロップフレーム枠線
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(currentCropFrame)
        
        // グリッド線（ドラッグ中のみ表示）
        if isDragging {
            drawGrid(in: context, frame: currentCropFrame)
        }
    }
    
    private func drawGrid(in context: CGContext, frame: CGRect) {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        
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
}

// MARK: - ProCrop Handle View
class ProCropHandleView: UIView {
    
    // MARK: - Properties
    private let handleType: ProCropFrameView.HandleType
    
    var onDragBegan: ((CGPoint) -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    private var panGesture: UIPanGestureRecognizer!
    
    // MARK: - Initialization
    init(type: ProCropFrameView.HandleType) {
        self.handleType = type
        super.init(frame: .zero)
        setupGesture()
        backgroundColor = UIColor.clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)
    }
    
    // MARK: - Gesture Handler
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        
        switch gesture.state {
        case .began:
            let location = gesture.location(in: superview)
            onDragBegan?(location)
            
        case .changed:
            onDragChanged?(translation)
            
        case .ended, .cancelled:
            onDragEnded?()
            
        default:
            break
        }
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let visualRadius: CGFloat = 4
        
        // 透明なタッチ領域（デバッグ時のみ表示）
        #if DEBUG
        context.setFillColor(UIColor.blue.withAlphaComponent(0.1).cgColor)
        context.fillEllipse(in: bounds)
        #endif
        
        // 視覚的ハンドル
        if handleType.isCorner {
            // コーナーハンドル: L字型
            drawCornerHandle(in: context, center: center, radius: visualRadius)
        } else {
            // エッジハンドル: 小さな円
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: CGRect(
                x: center.x - visualRadius / 2,
                y: center.y - visualRadius / 2,
                width: visualRadius,
                height: visualRadius
            ))
        }
    }
    
    private func drawCornerHandle(in context: CGContext, center: CGPoint, radius: CGFloat) {
        let lineLength: CGFloat = 20
        let lineWidth: CGFloat = 3
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        
        var horizontal: (CGPoint, CGPoint)
        var vertical: (CGPoint, CGPoint)
        
        switch handleType {
        case .topLeft:
            horizontal = (CGPoint(x: center.x - radius, y: center.y), CGPoint(x: center.x + lineLength, y: center.y))
            vertical = (CGPoint(x: center.x, y: center.y - radius), CGPoint(x: center.x, y: center.y + lineLength))
            
        case .topRight:
            horizontal = (CGPoint(x: center.x - lineLength, y: center.y), CGPoint(x: center.x + radius, y: center.y))
            vertical = (CGPoint(x: center.x, y: center.y - radius), CGPoint(x: center.x, y: center.y + lineLength))
            
        case .bottomLeft:
            horizontal = (CGPoint(x: center.x - radius, y: center.y), CGPoint(x: center.x + lineLength, y: center.y))
            vertical = (CGPoint(x: center.x, y: center.y - lineLength), CGPoint(x: center.x, y: center.y + radius))
            
        case .bottomRight:
            horizontal = (CGPoint(x: center.x - lineLength, y: center.y), CGPoint(x: center.x + radius, y: center.y))
            vertical = (CGPoint(x: center.x, y: center.y - lineLength), CGPoint(x: center.x, y: center.y + radius))
            
        default:
            return
        }
        
        // 水平線
        context.move(to: horizontal.0)
        context.addLine(to: horizontal.1)
        
        // 垂直線
        context.move(to: vertical.0)
        context.addLine(to: vertical.1)
        
        context.strokePath()
    }
}