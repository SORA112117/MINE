import UIKit
import AVFoundation

// MARK: - ProCrop Content View
/// 動画コンテンツの表示とズーム・パン操作を担当
/// iPhone純正写真アプリのように、クロップフレーム内で動画を動かす
class ProCropContentView: UIView {
    
    // MARK: - Properties
    private let playerLayer: AVPlayerLayer
    private let videoSize: CGSize
    
    // ジェスチャー
    private var panGesture: UIPanGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!
    
    // 変形パラメータ
    private var contentScale: CGFloat = 1.0
    private var contentTranslation: CGPoint = .zero
    private var lastScale: CGFloat = 1.0
    private var lastTranslation: CGPoint = .zero
    
    // 座標系
    private var videoDisplayRect: CGRect = .zero
    private var baseTransform: CGAffineTransform = .identity
    
    // コールバック
    var onContentTransformed: (() -> Void)?
    
    // MARK: - Initialization
    init(player: AVPlayer, videoSize: CGSize) {
        self.playerLayer = AVPlayerLayer(player: player)
        self.videoSize = videoSize
        
        super.init(frame: .zero)
        setupPlayerLayer()
        setupGestures()
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
        // フレーム内でのジェスチャーのみ有効
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        
        addGestureRecognizer(panGesture)
        addGestureRecognizer(pinchGesture)
        
        panGesture.delegate = self
        pinchGesture.delegate = self
        
        // ジェスチャーの有効範囲を制限
        panGesture.cancelsTouchesInView = false
        pinchGesture.cancelsTouchesInView = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePlayerLayerFrame()
    }
    
    // MARK: - Public Methods
    func updateVideoDisplayRect(_ rect: CGRect) {
        videoDisplayRect = rect
        updatePlayerLayerFrame()
        resetContentTransform()
    }
    
    // MARK: - Private Methods
    private func updatePlayerLayerFrame() {
        // プレイヤーレイヤーは常に動画表示領域に配置
        playerLayer.frame = videoDisplayRect
        
        // 現在の変形を適用
        applyContentTransform()
    }
    
    private func resetContentTransform() {
        contentScale = 1.0
        contentTranslation = .zero
        lastScale = 1.0
        lastTranslation = .zero
        applyContentTransform()
    }
    
    private func applyContentTransform() {
        // スケール変形
        let scaleTransform = CGAffineTransform(scaleX: contentScale, y: contentScale)
        
        // 平行移動変形
        let translationTransform = CGAffineTransform(translationX: contentTranslation.x, y: contentTranslation.y)
        
        // 合成変形
        let combinedTransform = scaleTransform.concatenating(translationTransform)
        
        // プレイヤーレイヤーに適用
        playerLayer.setAffineTransform(combinedTransform)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // クロップフレーム内でのジェスチャーのみ処理
        guard videoDisplayRect.contains(location) else { return }
        
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began:
            lastTranslation = contentTranslation
            
        case .changed:
            let newTranslation = CGPoint(
                x: lastTranslation.x + translation.x,
                y: lastTranslation.y + translation.y
            )
            
            // 弾性境界で制限
            contentTranslation = constrainTranslationWithElasticity(newTranslation)
            applyContentTransform()
            
        case .ended, .cancelled:
            // 境界外の場合は元に戻す
            contentTranslation = constrainTranslation(contentTranslation)
            lastTranslation = contentTranslation
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.applyContentTransform()
            }
            
            onContentTransformed?()
            
        default:
            break
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: self)
        
        // クロップフレーム内でのジェスチャーのみ処理
        guard videoDisplayRect.contains(location) else { return }
        
        let scale = gesture.scale
        
        switch gesture.state {
        case .began:
            lastScale = contentScale
            
        case .changed:
            let newScale = lastScale * scale
            
            // スケール制限（0.5x - 3.0x）
            contentScale = max(0.5, min(3.0, newScale))
            applyContentTransform()
            
        case .ended, .cancelled:
            lastScale = contentScale
            onContentTransformed?()
            
        default:
            break
        }
    }
    
    // MARK: - Constraints
    
    /// 弾性境界付き平行移動制限
    private func constrainTranslationWithElasticity(_ translation: CGPoint) -> CGPoint {
        let hardLimit = constrainTranslation(translation)
        
        // 境界を超えた場合は弾性効果を適用
        let elasticFactor: CGFloat = 0.3
        
        var elasticX = translation.x
        var elasticY = translation.y
        
        if translation.x != hardLimit.x {
            let overflow = translation.x - hardLimit.x
            elasticX = hardLimit.x + overflow * elasticFactor
        }
        
        if translation.y != hardLimit.y {
            let overflow = translation.y - hardLimit.y
            elasticY = hardLimit.y + overflow * elasticFactor
        }
        
        return CGPoint(x: elasticX, y: elasticY)
    }
    
    /// 厳密な平行移動制限
    private func constrainTranslation(_ translation: CGPoint) -> CGPoint {
        guard !videoDisplayRect.isEmpty else { return translation }
        
        // スケール後の動画サイズ
        let scaledWidth = videoDisplayRect.width * contentScale
        let scaledHeight = videoDisplayRect.height * contentScale
        
        // 最大移動可能距離
        let maxTranslationX = max(0, (scaledWidth - videoDisplayRect.width) / 2)
        let maxTranslationY = max(0, (scaledHeight - videoDisplayRect.height) / 2)
        
        let constrainedX = max(-maxTranslationX, min(maxTranslationX, translation.x))
        let constrainedY = max(-maxTranslationY, min(maxTranslationY, translation.y))
        
        return CGPoint(x: constrainedX, y: constrainedY)
    }
}

// MARK: - Gesture Recognizer Delegate
extension ProCropContentView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // ピンチとパンの同時操作を許可
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self)
        // 動画表示領域内でのジェスチャーのみ開始
        return videoDisplayRect.contains(location)
    }
}