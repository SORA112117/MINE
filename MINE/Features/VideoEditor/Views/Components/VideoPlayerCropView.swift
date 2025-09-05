import SwiftUI
import AVKit
import AVFoundation
import Combine

// MARK: - Video Player with Hybrid Crop System
/// 最高の精度と信頼性を実現するハイブリッドクロップシステム
/// UltraCropSystemの状態管理 + SwiftUIの宣言的UI
struct VideoPlayerCropView: View {
    let player: AVPlayer
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    var body: some View {
        HybridCropView(
            player: player,
            videoSize: videoSize,
            cropRect: $cropRect,
            aspectRatio: aspectRatio,
            showCropOverlay: showCropOverlay,
            onCropChanged: onCropChanged
        )
    }
}

// MARK: - Hybrid Crop System Implementation
/// UltraCropSystemの高度な状態管理 + SwiftUIの宣言的UI
struct HybridCropView: View {
    let player: AVPlayer
    let videoSize: CGSize
    @Binding var cropRect: CGRect
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    // MARK: - State Management
    @StateObject private var cropController = CropController()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Player - 確実な表示
                VideoPlayer(player: player)
                    .disabled(true)
                    .onAppear {
                        cropController.setup(
                            containerSize: geometry.size,
                            videoSize: videoSize,
                            aspectRatio: aspectRatio
                        )
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        cropController.updateContainerSize(newSize)
                    }
                    .onChange(of: aspectRatio) { _, newRatio in
                        cropController.updateAspectRatio(newRatio)
                    }
                
                if showCropOverlay && cropController.isReady {
                    HybridCropOverlayView(controller: cropController)
                        .onReceive(cropController.$videoCropRect) { rect in
                            cropRect = rect
                            onCropChanged(rect)
                        }
                }
            }
        }
    }
}

// MARK: - Crop Controller (HTMLアルゴリズムベース状態管理)
class CropController: ObservableObject {
    
    // MARK: - Types
    enum CropState {
        case idle, dragging, resizing, moving
    }
    
    enum HandleType: String, CaseIterable {
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
    
    // MARK: - Published Properties
    @Published var isReady: Bool = false
    @Published var cropRect: CGRect = .zero
    @Published var videoCropRect: CGRect = .zero
    @Published var currentState: CropState = .idle
    @Published var activeHandle: HandleType?
    
    // MARK: - Private Properties
    private var containerSize: CGSize = .zero
    private var videoSize: CGSize = .zero
    private var videoDisplayRect: CGRect = .zero
    private var aspectRatio: CropAspectRatio = .free
    private var maintainAspectRatio: Bool = false
    private var targetAspectRatio: CGFloat = 1.0
    
    // Touch tracking
    private var touchStartPoint: CGPoint = .zero
    private var startFrame: CGRect = .zero
    private var moveOffset: CGPoint = .zero
    
    // Constraints
    private let minCropSize: CGFloat = 20
    private let handleSize: CGFloat = 44
    
    // MARK: - Setup Methods
    func setup(containerSize: CGSize, videoSize: CGSize, aspectRatio: CropAspectRatio) {
        self.containerSize = containerSize
        self.videoSize = videoSize
        self.aspectRatio = aspectRatio
        
        updateVideoDisplayRect()
        createDefaultCropRect()
        
        isReady = true
    }
    
    func updateContainerSize(_ size: CGSize) {
        containerSize = size
        updateVideoDisplayRect()
        constrainCropRect()
    }
    
    func updateAspectRatio(_ ratio: CropAspectRatio) {
        aspectRatio = ratio
        applyCropAspectRatio()
    }
    
    // MARK: - Core Algorithm (UltraCropSystemから移植)
    private func updateVideoDisplayRect() {
        guard containerSize != .zero && videoSize.width > 0 && videoSize.height > 0 else {
            videoDisplayRect = .zero
            return
        }
        
        let videoAspectRatio = videoSize.width / videoSize.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if videoAspectRatio > containerAspectRatio {
            // Video is wider - fit to width
            let displayWidth = containerSize.width
            let displayHeight = displayWidth / videoAspectRatio
            let y = (containerSize.height - displayHeight) / 2
            videoDisplayRect = CGRect(x: 0, y: y, width: displayWidth, height: displayHeight)
        } else {
            // Video is taller - fit to height
            let displayHeight = containerSize.height
            let displayWidth = displayHeight * videoAspectRatio
            let x = (containerSize.width - displayWidth) / 2
            videoDisplayRect = CGRect(x: x, y: 0, width: displayWidth, height: displayHeight)
        }
    }
    
    private func createDefaultCropRect() {
        guard !videoDisplayRect.isEmpty else { return }
        
        let margin: CGFloat = 20
        cropRect = videoDisplayRect.insetBy(dx: margin, dy: margin)
        applyCropAspectRatio()
        updateVideoCropRect()
    }
    
    private func applyCropAspectRatio() {
        switch aspectRatio {
        case .free:
            maintainAspectRatio = false
            return
        case .square:
            targetAspectRatio = 1.0
        case .portrait:
            targetAspectRatio = 9.0 / 16.0
        case .landscape:
            targetAspectRatio = 16.0 / 9.0
        }
        
        maintainAspectRatio = true
        
        // Apply aspect ratio while preserving position
        let currentCenter = CGPoint(x: cropRect.midX, y: cropRect.midY)
        let currentSize = cropRect.size
        
        var newSize: CGSize
        let currentRatio = currentSize.width / currentSize.height
        
        if currentRatio > targetAspectRatio {
            newSize = CGSize(
                width: currentSize.height * targetAspectRatio,
                height: currentSize.height
            )
        } else {
            newSize = CGSize(
                width: currentSize.width,
                height: currentSize.width / targetAspectRatio
            )
        }
        
        // Constrain to video bounds
        newSize.width = min(newSize.width, videoDisplayRect.width)
        newSize.height = min(newSize.height, videoDisplayRect.height)
        
        cropRect = CGRect(
            x: currentCenter.x - newSize.width / 2,
            y: currentCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
        
        constrainCropRect()
    }
    
    // MARK: - HTMLアルゴリズムベースタッチ判定
    func determineTouchAction(at point: CGPoint) -> CropState {
        // Step 1: Handle detection (strict)
        if let handle = detectHandle(at: point) {
            activeHandle = handle
            return .resizing
        }
        
        // Step 2: Crop area check
        if cropRect.contains(point) && !isNearAnyHandle(point) {
            return .moving
        }
        
        // Step 3: New drag
        return .dragging
    }
    
    private func detectHandle(at point: CGPoint) -> HandleType? {
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
        let exclusionRadius = handleSize / 2
        
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
    
    func calculateHandlePositions() -> [HandleType: CGPoint] {
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
    func startGesture(at point: CGPoint) {
        currentState = determineTouchAction(at: point)
        touchStartPoint = point
        
        switch currentState {
        case .resizing:
            startFrame = cropRect
        case .moving:
            moveOffset = CGPoint(
                x: point.x - cropRect.midX,
                y: point.y - cropRect.midY
            )
        case .dragging:
            cropRect = CGRect(origin: point, size: .zero)
        case .idle:
            break
        }
    }
    
    func updateGesture(at point: CGPoint) {
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
    
    func endGesture() {
        constrainCropRect()
        currentState = .idle
        activeHandle = nil
    }
    
    // MARK: - Private Gesture Methods
    private func handleResize(to point: CGPoint) {
        guard let handle = activeHandle else { return }
        
        let translation = CGPoint(
            x: point.x - touchStartPoint.x,
            y: point.y - touchStartPoint.y
        )
        
        var newFrame = startFrame
        
        // HTMLアルゴリズムベースリサイズ処理
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
        
        cropRect = newFrame
        updateVideoCropRect()
    }
    
    private func handleMove(to point: CGPoint) {
        let newCenterX = point.x - moveOffset.x
        let newCenterY = point.y - moveOffset.y
        
        cropRect = CGRect(
            x: newCenterX - cropRect.width / 2,
            y: newCenterY - cropRect.height / 2,
            width: cropRect.width,
            height: cropRect.height
        )
        
        updateVideoCropRect()
    }
    
    private func handleDrag(to point: CGPoint) {
        let minX = min(touchStartPoint.x, point.x)
        let minY = min(touchStartPoint.y, point.y)
        let maxX = max(touchStartPoint.x, point.x)
        let maxY = max(touchStartPoint.y, point.y)
        
        cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        updateVideoCropRect()
    }
    
    // MARK: - 制約メソッド
    private func constrainCropRect() {
        cropRect = constrainFrame(cropRect, to: videoDisplayRect)
        updateVideoCropRect()
    }
    
    private func constrainFrame(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var constrained = rect
        
        // サイズ制約
        constrained.size.width = max(minCropSize, min(constrained.size.width, bounds.width))
        constrained.size.height = max(minCropSize, min(constrained.size.height, bounds.height))
        
        // 位置制約
        if constrained.minX < bounds.minX {
            constrained.origin.x = bounds.minX
        }
        if constrained.minY < bounds.minY {
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
    
    private func enforceAspectRatio(_ frame: CGRect, handle: HandleType) -> CGRect {
        var constrainedFrame = frame
        let currentRatio = frame.width / frame.height
        
        if handle.isCorner {
            if currentRatio > targetAspectRatio {
                constrainedFrame.size.height = frame.width / targetAspectRatio
            } else {
                constrainedFrame.size.width = frame.height * targetAspectRatio
            }
            
            // Position adjustment based on handle
            switch handle {
            case .topLeft:
                constrainedFrame.origin.x = frame.maxX - constrainedFrame.width
                constrainedFrame.origin.y = frame.maxY - constrainedFrame.height
            case .topRight:
                constrainedFrame.origin.y = frame.maxY - constrainedFrame.height
            case .bottomLeft:
                constrainedFrame.origin.x = frame.maxX - constrainedFrame.width
            case .bottomRight:
                // No adjustment needed
                break
            default:
                break
            }
        }
        
        return constrainedFrame
    }
    
    private func updateVideoCropRect() {
        guard !videoDisplayRect.isEmpty && videoSize.width > 0 && videoSize.height > 0 else {
            videoCropRect = .zero
            return
        }
        
        let relativeX = (cropRect.origin.x - videoDisplayRect.origin.x) / videoDisplayRect.width
        let relativeY = (cropRect.origin.y - videoDisplayRect.origin.y) / videoDisplayRect.height
        let relativeWidth = cropRect.width / videoDisplayRect.width
        let relativeHeight = cropRect.height / videoDisplayRect.height
        
        videoCropRect = CGRect(
            x: relativeX * videoSize.width,
            y: relativeY * videoSize.height,
            width: relativeWidth * videoSize.width,
            height: relativeHeight * videoSize.height
        )
    }
}

// MARK: - Hybrid Crop Overlay View (SwiftUI宣言的UI)
struct HybridCropOverlayView: View {
    @ObservedObject var controller: CropController
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay with cutout
            overlayMask
            
            // Crop frame and grid
            cropFrame
            
            // Resize handles
            resizeHandles
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if controller.currentState == .idle {
                        controller.startGesture(at: value.startLocation)
                    }
                    controller.updateGesture(at: value.location)
                }
                .onEnded { _ in
                    controller.endGesture()
                }
        )
    }
    
    // MARK: - Overlay Components
    private var overlayMask: some View {
        Color.black.opacity(0.6)
            .mask(
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        Rectangle()
                            .frame(width: controller.cropRect.width, height: controller.cropRect.height)
                            .position(x: controller.cropRect.midX, y: controller.cropRect.midY)
                            .blendMode(.destinationOut)
                    )
            )
    }
    
    private var cropFrame: some View {
        ZStack {
            // Main frame border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: controller.cropRect.width, height: controller.cropRect.height)
                .position(x: controller.cropRect.midX, y: controller.cropRect.midY)
            
            // Grid lines
            gridLines
        }
    }
    
    private var gridLines: some View {
        ZStack {
            // Vertical lines
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 1)
                    .position(
                        x: controller.cropRect.minX + (controller.cropRect.width / 3) * CGFloat(i),
                        y: controller.cropRect.midY
                    )
                    .frame(height: controller.cropRect.height)
            }
            
            // Horizontal lines
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                    .position(
                        x: controller.cropRect.midX,
                        y: controller.cropRect.minY + (controller.cropRect.height / 3) * CGFloat(i)
                    )
                    .frame(width: controller.cropRect.width)
            }
        }
    }
    
    private var resizeHandles: some View {
        let handles = controller.calculateHandlePositions()
        
        return ZStack {
            ForEach(CropController.HandleType.allCases, id: \.rawValue) { handleType in
                if let position = handles[handleType] {
                    Circle()
                        .fill(Color.white)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 12, height: 12)
                        .position(position)
                        .scaleEffect(controller.activeHandle == handleType ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: controller.activeHandle)
                }
            }
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