import SwiftUI
import UIKit

// MARK: - Image Cropper View
struct ImageCropperView: View {
    let imageURL: URL
    let onCrop: (URL) -> Void
    
    @State private var image: UIImage?
    @State private var cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    ImageCropView(
                        image: image,
                        cropRect: $cropRect
                    )
                } else {
                    ProgressView("画像を読み込み中...")
                        .foregroundColor(.white)
                }
                
                // エラーメッセージ
                if let errorMessage = errorMessage {
                    VStack {
                        Spacer()
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .padding()
                    }
                }
                
                // 処理中オーバーレイ
                if isProcessing {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("クロッピング中...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            }
            .navigationTitle("画像をクロップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        cropImage()
                    }
                    .foregroundColor(.white)
                    .disabled(isProcessing)
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        Task {
            do {
                let data = try Data(contentsOf: imageURL)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = uiImage
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "画像の読み込みに失敗しました"
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func cropImage() {
        guard let image = image else { return }
        
        isProcessing = true
        
        Task {
            do {
                let croppedImage = cropUIImage(image, to: cropRect)
                let croppedURL = try await saveCroppedImage(croppedImage)
                
                await MainActor.run {
                    onCrop(croppedURL)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "クロッピングに失敗しました: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func cropUIImage(_ image: UIImage, to rect: CGRect) -> UIImage {
        let imageSize = image.size
        let cropArea = CGRect(
            x: rect.minX * imageSize.width,
            y: rect.minY * imageSize.height,
            width: rect.width * imageSize.width,
            height: rect.height * imageSize.height
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropArea) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func saveCroppedImage(_ image: UIImage) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ImageCropperError.failedToGenerateData
        }
        
        let filename = "cropped_\(Date().timeIntervalSince1970).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Image Crop View
struct ImageCropView: UIViewRepresentable {
    let image: UIImage
    @Binding var cropRect: CGRect
    
    func makeUIView(context: Context) -> ImageCropUIView {
        let cropView = ImageCropUIView()
        cropView.image = image
        cropView.cropRect = cropRect
        cropView.onCropRectChanged = { newRect in
            cropRect = newRect
        }
        return cropView
    }
    
    func updateUIView(_ uiView: ImageCropUIView, context: Context) {
        if uiView.cropRect != cropRect {
            uiView.cropRect = cropRect
        }
    }
}

// MARK: - Image Crop UI View
class ImageCropUIView: UIView {
    var image: UIImage? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var onCropRectChanged: ((CGRect) -> Void)?
    private var isDragging = false
    private var dragHandle: DragHandle = .none
    
    enum DragHandle {
        case none, topLeft, topRight, bottomLeft, bottomRight, center
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(panGesture)
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let image = image else { return }
        
        // 背景を黒で塗りつぶし
        context.setFillColor(UIColor.black.cgColor)
        context.fill(rect)
        
        // 画像のアスペクト比を保持して描画
        let imageRect = aspectFillRect(for: image.size, in: rect)
        image.draw(in: imageRect)
        
        // クロップエリア外を半透明で覆う
        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        
        let cropFrame = CGRect(
            x: imageRect.minX + cropRect.minX * imageRect.width,
            y: imageRect.minY + cropRect.minY * imageRect.height,
            width: cropRect.width * imageRect.width,
            height: cropRect.height * imageRect.height
        )
        
        // 上部
        context.fill(CGRect(x: 0, y: 0, width: rect.width, height: cropFrame.minY))
        // 下部
        context.fill(CGRect(x: 0, y: cropFrame.maxY, width: rect.width, height: rect.maxY - cropFrame.maxY))
        // 左部
        context.fill(CGRect(x: 0, y: cropFrame.minY, width: cropFrame.minX, height: cropFrame.height))
        // 右部
        context.fill(CGRect(x: cropFrame.maxX, y: cropFrame.minY, width: rect.maxX - cropFrame.maxX, height: cropFrame.height))
        
        // クロップ枠の描画
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.stroke(cropFrame)
        
        // コーナーハンドルの描画
        let handleSize: CGFloat = 20
        let handles = [
            CGRect(x: cropFrame.minX - handleSize/2, y: cropFrame.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: cropFrame.maxX - handleSize/2, y: cropFrame.minY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: cropFrame.minX - handleSize/2, y: cropFrame.maxY - handleSize/2, width: handleSize, height: handleSize),
            CGRect(x: cropFrame.maxX - handleSize/2, y: cropFrame.maxY - handleSize/2, width: handleSize, height: handleSize)
        ]
        
        context.setFillColor(UIColor.white.cgColor)
        for handle in handles {
            context.fill(handle)
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        
        switch gesture.state {
        case .began:
            dragHandle = getDragHandle(at: location)
            isDragging = true
            
        case .changed:
            if isDragging {
                updateCropRect(with: gesture.translation(in: self), handle: dragHandle)
                gesture.setTranslation(.zero, in: self)
            }
            
        case .ended, .cancelled:
            isDragging = false
            dragHandle = .none
            
        default:
            break
        }
    }
    
    private func getDragHandle(at point: CGPoint) -> DragHandle {
        guard let image = image else { return .none }
        
        let imageRect = aspectFillRect(for: image.size, in: bounds)
        let cropFrame = CGRect(
            x: imageRect.minX + cropRect.minX * imageRect.width,
            y: imageRect.minY + cropRect.minY * imageRect.height,
            width: cropRect.width * imageRect.width,
            height: cropRect.height * imageRect.height
        )
        
        let handleSize: CGFloat = 30
        
        // コーナーハンドルのチェック
        if CGRect(x: cropFrame.minX - handleSize/2, y: cropFrame.minY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .topLeft
        }
        if CGRect(x: cropFrame.maxX - handleSize/2, y: cropFrame.minY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .topRight
        }
        if CGRect(x: cropFrame.minX - handleSize/2, y: cropFrame.maxY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .bottomLeft
        }
        if CGRect(x: cropFrame.maxX - handleSize/2, y: cropFrame.maxY - handleSize/2, width: handleSize, height: handleSize).contains(point) {
            return .bottomRight
        }
        if cropFrame.contains(point) {
            return .center
        }
        
        return .none
    }
    
    private func updateCropRect(with translation: CGPoint, handle: DragHandle) {
        guard let image = image else { return }
        
        let imageRect = aspectFillRect(for: image.size, in: bounds)
        let normalizedTranslation = CGPoint(
            x: translation.x / imageRect.width,
            y: translation.y / imageRect.height
        )
        
        var newRect = cropRect
        
        switch handle {
        case .topLeft:
            newRect.origin.x += normalizedTranslation.x
            newRect.origin.y += normalizedTranslation.y
            newRect.size.width -= normalizedTranslation.x
            newRect.size.height -= normalizedTranslation.y
            
        case .topRight:
            newRect.origin.y += normalizedTranslation.y
            newRect.size.width += normalizedTranslation.x
            newRect.size.height -= normalizedTranslation.y
            
        case .bottomLeft:
            newRect.origin.x += normalizedTranslation.x
            newRect.size.width -= normalizedTranslation.x
            newRect.size.height += normalizedTranslation.y
            
        case .bottomRight:
            newRect.size.width += normalizedTranslation.x
            newRect.size.height += normalizedTranslation.y
            
        case .center:
            newRect.origin.x += normalizedTranslation.x
            newRect.origin.y += normalizedTranslation.y
            
        case .none:
            return
        }
        
        // 境界制限
        newRect = constrainRect(newRect)
        
        cropRect = newRect
        onCropRectChanged?(newRect)
        setNeedsDisplay()
    }
    
    private func constrainRect(_ rect: CGRect) -> CGRect {
        let minSize: CGFloat = 0.1
        
        var constrained = rect
        
        // 最小サイズの確保
        constrained.size.width = max(minSize, constrained.size.width)
        constrained.size.height = max(minSize, constrained.size.height)
        
        // 境界内に収める
        constrained.origin.x = max(0, min(1.0 - constrained.size.width, constrained.origin.x))
        constrained.origin.y = max(0, min(1.0 - constrained.size.height, constrained.origin.y))
        
        // 右端と下端の調整
        if constrained.maxX > 1.0 {
            constrained.origin.x = 1.0 - constrained.size.width
        }
        if constrained.maxY > 1.0 {
            constrained.origin.y = 1.0 - constrained.size.height
        }
        
        return constrained
    }
    
    private func aspectFillRect(for imageSize: CGSize, in containerRect: CGRect) -> CGRect {
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerRect.width / containerRect.height
        
        let rect: CGRect
        if imageAspectRatio > containerAspectRatio {
            // 画像の方が横長
            let height = containerRect.height
            let width = height * imageAspectRatio
            rect = CGRect(x: containerRect.midX - width/2, y: containerRect.minY, width: width, height: height)
        } else {
            // 画像の方が縦長
            let width = containerRect.width
            let height = width / imageAspectRatio
            rect = CGRect(x: containerRect.minX, y: containerRect.midY - height/2, width: width, height: height)
        }
        
        return rect
    }
}

// MARK: - Image Cropper Error
enum ImageCropperError: LocalizedError {
    case failedToGenerateData
    
    var errorDescription: String? {
        switch self {
        case .failedToGenerateData:
            return "画像データの生成に失敗しました"
        }
    }
}