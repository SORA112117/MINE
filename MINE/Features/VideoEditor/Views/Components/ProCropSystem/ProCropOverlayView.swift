import UIKit

// MARK: - ProCrop Overlay View
/// マスクとグリッドの視覚的フィードバックを担当
/// クロップ領域外を暗くし、操作中のグリッドを表示
class ProCropOverlayView: UIView {
    
    // MARK: - Properties
    private var cropArea: CGRect = .zero
    private var videoDisplayRect: CGRect = .zero
    private var showGrid: Bool = false
    
    // アニメーション
    private var gridAnimator: UIViewPropertyAnimator?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = false // タッチを通す
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = UIColor.clear
        isUserInteractionEnabled = false
    }
    
    // MARK: - Public Methods
    func updateCropArea(_ cropRect: CGRect, videoDisplayRect: CGRect) {
        self.cropArea = cropRect
        self.videoDisplayRect = videoDisplayRect
        
        DispatchQueue.main.async {
            self.setNeedsDisplay()
        }
    }
    
    func showGrid(animated: Bool = true) {
        guard !showGrid else { return }
        showGrid = true
        
        if animated {
            gridAnimator?.stopAnimation(true)
            gridAnimator = UIViewPropertyAnimator(duration: 0.2, dampingRatio: 0.8) {
                self.setNeedsDisplay()
            }
            gridAnimator?.startAnimation()
        } else {
            setNeedsDisplay()
        }
    }
    
    func hideGrid(animated: Bool = true) {
        guard showGrid else { return }
        showGrid = false
        
        if animated {
            gridAnimator?.stopAnimation(true)
            gridAnimator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.8) {
                self.setNeedsDisplay()
            }
            gridAnimator?.startAnimation()
        } else {
            setNeedsDisplay()
        }
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext(),
              !videoDisplayRect.isEmpty,
              !cropArea.isEmpty else { return }
        
        // 全画面を暗くする
        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
        
        // 動画表示領域をクリア（動画を見えるようにする）
        context.setBlendMode(.clear)
        context.fill(videoDisplayRect)
        context.setBlendMode(.normal)
        
        // 動画表示領域内のクロップ領域外を暗くする
        drawCropMask(in: context)
        
        // クロップ領域の境界線
        drawCropBorder(in: context)
        
        // グリッド線（必要時）
        if showGrid {
            drawGrid(in: context)
        }
        
        // 動画表示領域の境界線（デバッグ用、薄く）
        #if DEBUG
        drawVideoDisplayBorder(in: context)
        #endif
    }
    
    private func drawCropMask(in context: CGContext) {
        // 動画表示領域内で、クロップ領域外の部分を暗くする
        let maskPath = UIBezierPath(rect: videoDisplayRect)
        let cropPath = UIBezierPath(rect: cropArea)
        maskPath.append(cropPath.reversing())
        
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        maskPath.fill()
    }
    
    private func drawCropBorder(in context: CGContext) {
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(cropArea)
        
        // 内側に薄い境界線を追加（プロフェッショナルな見た目）
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1.0)
        context.stroke(cropArea.insetBy(dx: -1, dy: -1))
    }
    
    private func drawGrid(in context: CGContext) {
        guard !cropArea.isEmpty else { return }
        
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.0)
        
        let thirdWidth = cropArea.width / 3
        let thirdHeight = cropArea.height / 3
        
        // 3分割グリッド
        // 縦線
        for i in 1..<3 {
            let x = cropArea.origin.x + thirdWidth * CGFloat(i)
            context.move(to: CGPoint(x: x, y: cropArea.origin.y))
            context.addLine(to: CGPoint(x: x, y: cropArea.maxY))
        }
        
        // 横線
        for i in 1..<3 {
            let y = cropArea.origin.y + thirdHeight * CGFloat(i)
            context.move(to: CGPoint(x: cropArea.origin.x, y: y))
            context.addLine(to: CGPoint(x: cropArea.maxX, y: y))
        }
        
        context.strokePath()
        
        // 中心十字線（より目立つ）
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.5)
        
        let centerX = cropArea.midX
        let centerY = cropArea.midY
        
        // 中心縦線
        context.move(to: CGPoint(x: centerX, y: cropArea.origin.y))
        context.addLine(to: CGPoint(x: centerX, y: cropArea.maxY))
        
        // 中心横線
        context.move(to: CGPoint(x: cropArea.origin.x, y: centerY))
        context.addLine(to: CGPoint(x: cropArea.maxX, y: centerY))
        
        context.strokePath()
    }
    
    private func drawVideoDisplayBorder(in context: CGContext) {
        context.setStrokeColor(UIColor.blue.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [5, 5])
        context.stroke(videoDisplayRect)
        context.setLineDash(phase: 0, lengths: [])
    }
}

// MARK: - Animation Support
extension ProCropOverlayView {
    
    /// スムーズなクロップ領域更新アニメーション
    func animateToNewCropArea(_ newCropArea: CGRect, videoDisplayRect: CGRect, duration: TimeInterval = 0.3) {
        _ = self.cropArea
        _ = self.videoDisplayRect
        
        // アニメーター作成
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.8) {
            // アニメーション中は直接プロパティを更新せず、drawで補間
        }
        
        animator.addAnimations {
            // カスタム描画更新
            let displayLink = CADisplayLink(target: self, selector: #selector(self.updateInterpolation))
            displayLink.add(to: .current, forMode: .default)
            
            // アニメーション完了時にdisplayLinkを停止
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                displayLink.invalidate()
                self.cropArea = newCropArea
                self.videoDisplayRect = videoDisplayRect
                self.setNeedsDisplay()
            }
        }
        
        animator.startAnimation()
    }
    
    @objc private func updateInterpolation() {
        // 補間ロジックが必要な場合はここで実装
        // 現在は基本的な更新のみ
        setNeedsDisplay()
    }
    
    /// パルス効果でユーザーの注意を引く
    func pulseHighlight() {
        let pulseLayer = CAShapeLayer()
        pulseLayer.path = UIBezierPath(rect: cropArea).cgPath
        pulseLayer.fillColor = UIColor.clear.cgColor
        pulseLayer.strokeColor = UIColor.white.cgColor
        pulseLayer.lineWidth = 4
        layer.addSublayer(pulseLayer)
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.05
        scaleAnimation.duration = 0.6
        scaleAnimation.autoreverses = true
        scaleAnimation.repeatCount = 2
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = 1.2
        
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [scaleAnimation, opacityAnimation]
        groupAnimation.duration = 1.2
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            pulseLayer.removeFromSuperlayer()
        }
        pulseLayer.add(groupAnimation, forKey: "pulse")
        CATransaction.commit()
    }
}