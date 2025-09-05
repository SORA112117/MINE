import SwiftUI
import UIKit
import AVFoundation

// MARK: - Professional Crop View
struct ProfessionalCropView: UIViewRepresentable {
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let onCropChanged: (CGRect) -> Void
    
    func makeUIView(context: Context) -> CropScrollView {
        let scrollView = CropScrollView(
            videoSize: videoSize,
            aspectRatio: aspectRatio
        ) { newRect in
            cropRect = newRect
            onCropChanged(newRect)
        }
        
        return scrollView
    }
    
    func updateUIView(_ uiView: CropScrollView, context: Context) {
        uiView.updateAspectRatio(aspectRatio)
    }
}

// MARK: - Crop Scroll View (UIScrollView-based)
class CropScrollView: UIView {
    
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let containerView = UIView()
    private let cropOverlayView = CropOverlayView()
    private let videoSize: CGSize
    private var aspectRatio: CropAspectRatio
    private let onCropChanged: (CGRect) -> Void
    
    private var currentZoomScale: CGFloat = 1.0
    private var currentContentOffset: CGPoint = .zero
    
    // MARK: - Initialization
    init(videoSize: CGSize, aspectRatio: CropAspectRatio, onCropChanged: @escaping (CGRect) -> Void) {
        self.videoSize = videoSize
        self.aspectRatio = aspectRatio
        self.onCropChanged = onCropChanged
        super.init(frame: .zero)
        setupScrollView()
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupScrollView() {
        addSubview(scrollView)
        scrollView.addSubview(containerView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            containerView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        // ScrollView設定
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 3.0
        scrollView.zoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        
        // コンテナビューの背景色設定（デバッグ用）
        containerView.backgroundColor = UIColor.clear
    }
    
    private func setupOverlay() {
        addSubview(cropOverlayView)
        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cropOverlayView.topAnchor.constraint(equalTo: topAnchor),
            cropOverlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cropOverlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cropOverlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        cropOverlayView.isUserInteractionEnabled = false // オーバーレイはタッチを透過
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCropArea()
    }
    
    // MARK: - Public Methods
    func updateAspectRatio(_ newAspectRatio: CropAspectRatio) {
        aspectRatio = newAspectRatio
        updateCropArea()
    }
    
    // MARK: - Private Methods
    private func updateCropArea() {
        let viewBounds = bounds
        guard !viewBounds.isEmpty else { return }
        
        // アスペクト比に基づくクロップエリアの計算
        let cropFrame = calculateCropFrame(for: aspectRatio, in: viewBounds)
        cropOverlayView.updateCropFrame(cropFrame)
        
        // 動画座標系でのクロップ矩形を計算
        let videoCropRect = convertToVideoCoordinates(cropFrame: cropFrame)
        onCropChanged(videoCropRect)
    }
    
    private func calculateCropFrame(for ratio: CropAspectRatio, in bounds: CGRect) -> CGRect {
        let margin: CGFloat = 20
        let availableWidth = bounds.width - 2 * margin
        let availableHeight = bounds.height - 2 * margin
        
        var cropWidth: CGFloat
        var cropHeight: CGFloat
        
        switch ratio {
        case .free:
            // フリーの場合は80%のサイズ
            cropWidth = availableWidth * 0.8
            cropHeight = availableHeight * 0.8
            
        case .square:
            let size = min(availableWidth, availableHeight) * 0.8
            cropWidth = size
            cropHeight = size
            
        case .portrait: // 9:16
            if availableWidth * 16.0 / 9.0 <= availableHeight {
                cropWidth = availableWidth * 0.8
                cropHeight = cropWidth * 16.0 / 9.0
            } else {
                cropHeight = availableHeight * 0.8
                cropWidth = cropHeight * 9.0 / 16.0
            }
            
        case .landscape: // 16:9
            if availableWidth * 9.0 / 16.0 <= availableHeight {
                cropWidth = availableWidth * 0.8
                cropHeight = cropWidth * 9.0 / 16.0
            } else {
                cropHeight = availableHeight * 0.8
                cropWidth = cropHeight * 16.0 / 9.0
            }
        }
        
        let cropX = (bounds.width - cropWidth) / 2
        let cropY = (bounds.height - cropHeight) / 2
        
        return CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }
    
    private func convertToVideoCoordinates(cropFrame: CGRect) -> CGRect {
        let viewBounds = bounds
        guard !viewBounds.isEmpty else { return .zero }
        
        // スクロールビューの現在の状態を考慮
        let zoomScale = scrollView.zoomScale
        let contentOffset = scrollView.contentOffset
        
        // ビュー座標から動画座標への変換
        let scaleX = videoSize.width / viewBounds.width
        let scaleY = videoSize.height / viewBounds.height
        let scale = max(scaleX, scaleY) // アスペクトフィット
        
        // ズームとオフセットを考慮した座標変換
        let adjustedX = (cropFrame.origin.x + contentOffset.x / zoomScale) * scale
        let adjustedY = (cropFrame.origin.y + contentOffset.y / zoomScale) * scale
        let adjustedWidth = (cropFrame.width / zoomScale) * scale
        let adjustedHeight = (cropFrame.height / zoomScale) * scale
        
        // 動画の境界内に制限
        let finalX = max(0, min(adjustedX, videoSize.width - adjustedWidth))
        let finalY = max(0, min(adjustedY, videoSize.height - adjustedHeight))
        let finalWidth = min(adjustedWidth, videoSize.width - finalX)
        let finalHeight = min(adjustedHeight, videoSize.height - finalY)
        
        return CGRect(
            x: finalX,
            y: finalY,
            width: finalWidth,
            height: finalHeight
        )
    }
}

// MARK: - UIScrollViewDelegate
extension CropScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return containerView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        currentZoomScale = scrollView.zoomScale
        updateCropArea()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        currentContentOffset = scrollView.contentOffset
        updateCropArea()
    }
}

// MARK: - Crop Overlay View
class CropOverlayView: UIView {
    private var cropFrame: CGRect = .zero
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 全体を暗くする
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)
        
        // クロップエリアを透明にする
        context.setBlendMode(.clear)
        context.fill(cropFrame)
        
        // クロップ枠を描画
        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(cropFrame)
        
        // グリッドラインを描画
        drawGridLines(in: context)
        
        // コーナーハンドルを描画
        drawCornerHandles(in: context)
    }
    
    private func drawGridLines(in context: CGContext) {
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        
        let thirdWidth = cropFrame.width / 3
        let thirdHeight = cropFrame.height / 3
        
        // 縦線
        for i in 1..<3 {
            let x = cropFrame.origin.x + thirdWidth * CGFloat(i)
            context.move(to: CGPoint(x: x, y: cropFrame.origin.y))
            context.addLine(to: CGPoint(x: x, y: cropFrame.maxY))
        }
        
        // 横線
        for i in 1..<3 {
            let y = cropFrame.origin.y + thirdHeight * CGFloat(i)
            context.move(to: CGPoint(x: cropFrame.origin.x, y: y))
            context.addLine(to: CGPoint(x: cropFrame.maxX, y: y))
        }
        
        context.strokePath()
    }
    
    private func drawCornerHandles(in context: CGContext) {
        let handleSize: CGFloat = 20
        let lineLength: CGFloat = 6
        let lineWidth: CGFloat = 2
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(lineWidth)
        
        let corners = [
            cropFrame.origin, // 左上
            CGPoint(x: cropFrame.maxX, y: cropFrame.origin.y), // 右上
            CGPoint(x: cropFrame.origin.x, y: cropFrame.maxY), // 左下
            CGPoint(x: cropFrame.maxX, y: cropFrame.maxY) // 右下
        ]
        
        for corner in corners {
            // L字型のハンドルを描画
            context.move(to: CGPoint(x: corner.x, y: corner.y + lineLength))
            context.addLine(to: corner)
            context.addLine(to: CGPoint(x: corner.x + lineLength, y: corner.y))
            context.strokePath()
        }
    }
    
    func updateCropFrame(_ frame: CGRect) {
        cropFrame = frame
        setNeedsDisplay()
    }
}

