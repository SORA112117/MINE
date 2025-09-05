import SwiftUI
import AVFoundation

// MARK: - SwiftUI Native Crop View
/// 完全なSwiftUIベースクロッピングシステム
/// 提案されたGeometryReader + DragGesture + MagnificationGestureアプローチを実装

struct SwiftUICropView: View {
    let player: AVPlayer
    let videoSize: CGSize
    @Binding var cropRect: CGRect
    let aspectRatio: CropAspectRatio
    let showCropOverlay: Bool
    let onCropChanged: (CGRect) -> Void
    
    // MARK: - State Properties
    @State private var cropFrame: CGRect = .zero
    @State private var videoDisplayRect: CGRect = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isDragging: Bool = false
    @State private var isResizing: Bool = false
    
    // MARK: - Handle Properties
    @State private var activeHandle: HandleType?
    @State private var handleDragOffset: CGSize = .zero
    
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Player Layer
                VideoPlayer(player: player)
                    .disabled(true) // ビデオ操作を無効化
                    .onAppear {
                        setupVideoDisplayRect(in: geometry.size)
                    }
                    .onChange(of: geometry.size) { _ in
                        setupVideoDisplayRect(in: geometry.size)
                    }
                
                if showCropOverlay && !videoDisplayRect.isEmpty {
                    // Crop Overlay System
                    cropOverlayView
                        .clipped()
                }
            }
        }
    }
    
    // MARK: - Crop Overlay View
    private var cropOverlayView: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.6)
                .mask(
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            Rectangle()
                                .frame(width: cropFrame.width, height: cropFrame.height)
                                .position(x: cropFrame.midX, y: cropFrame.midY)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Crop frame with handles
            cropFrameView
        }
    }
    
    // MARK: - Crop Frame View
    private var cropFrameView: some View {
        ZStack {
            // Main crop frame
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .background(Color.clear)
                .frame(width: cropFrame.width, height: cropFrame.height)
                .position(x: cropFrame.midX, y: cropFrame.midY)
                .scaleEffect(scale)
                .offset(dragOffset)
                .gesture(
                    SimultaneousGesture(
                        // Move gesture
                        DragGesture()
                            .onChanged { value in
                                if !isResizing {
                                    isDragging = true
                                    dragOffset = CGSize(
                                        width: lastDragOffset.width + value.translation.x,
                                        height: lastDragOffset.height + value.translation.y
                                    )
                                    updateCropFrame()
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                lastDragOffset = dragOffset
                                constrainCropFrame()
                            },
                        
                        // Scale gesture
                        MagnificationGesture()
                            .onChanged { value in
                                if !isDragging {
                                    isResizing = true
                                    scale = lastScale * value
                                    updateCropFrame()
                                }
                            }
                            .onEnded { _ in
                                isResizing = false
                                lastScale = scale
                                constrainCropFrame()
                            }
                    )
                )
            
            // Grid lines
            gridLinesView
            
            // Resize handles
            ForEach(HandleType.allCases, id: \.rawValue) { handle in
                resizeHandleView(for: handle)
            }
        }
    }
    
    // MARK: - Grid Lines View
    private var gridLinesView: some View {
        ZStack {
            // Vertical grid lines
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 1)
                    .position(
                        x: cropFrame.minX + (cropFrame.width / 3) * CGFloat(i),
                        y: cropFrame.midY
                    )
                    .frame(height: cropFrame.height)
            }
            
            // Horizontal grid lines
            ForEach(1..<3) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 1)
                    .position(
                        x: cropFrame.midX,
                        y: cropFrame.minY + (cropFrame.height / 3) * CGFloat(i)
                    )
                    .frame(width: cropFrame.width)
            }
        }
        .scaleEffect(scale)
        .offset(dragOffset)
    }
    
    // MARK: - Resize Handle View
    private func resizeHandleView(for handle: HandleType) -> some View {
        Circle()
            .fill(Color.white)
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: 12, height: 12)
            .position(handlePosition(for: handle))
            .scaleEffect(scale)
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        activeHandle = handle
                        handleResize(handle: handle, translation: value.translation)
                    }
                    .onEnded { _ in
                        activeHandle = nil
                        constrainCropFrame()
                    }
            )
    }
    
    // MARK: - Helper Methods
    
    private func setupVideoDisplayRect(in containerSize: CGSize) {
        guard videoSize.width > 0 && videoSize.height > 0 else { return }
        
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
        
        // Initialize crop frame if not set
        if cropFrame == .zero {
            initializeCropFrame()
        }
    }
    
    private func initializeCropFrame() {
        let margin: CGFloat = 20
        cropFrame = videoDisplayRect.insetBy(dx: margin, dy: margin)
        applyCropAspectRatio()
    }
    
    private func applyCropAspectRatio() {
        guard aspectRatio != .free else { return }
        
        let targetRatio: CGFloat
        switch aspectRatio {
        case .square:
            targetRatio = 1.0
        case .portrait:
            targetRatio = 9.0 / 16.0
        case .landscape:
            targetRatio = 16.0 / 9.0
        case .free:
            return
        }
        
        let currentCenter = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
        let currentSize = cropFrame.size
        
        var newSize: CGSize
        let currentRatio = currentSize.width / currentSize.height
        
        if currentRatio > targetRatio {
            // Too wide - adjust based on height
            newSize = CGSize(
                width: currentSize.height * targetRatio,
                height: currentSize.height
            )
        } else {
            // Too tall - adjust based on width
            newSize = CGSize(
                width: currentSize.width,
                height: currentSize.width / targetRatio
            )
        }
        
        // Constrain to video bounds
        newSize.width = min(newSize.width, videoDisplayRect.width)
        newSize.height = min(newSize.height, videoDisplayRect.height)
        
        cropFrame = CGRect(
            x: currentCenter.x - newSize.width / 2,
            y: currentCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
        
        constrainCropFrame()
    }
    
    private func handlePosition(for handle: HandleType) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: cropFrame.minX, y: cropFrame.minY)
        case .topCenter:
            return CGPoint(x: cropFrame.midX, y: cropFrame.minY)
        case .topRight:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.minY)
        case .middleLeft:
            return CGPoint(x: cropFrame.minX, y: cropFrame.midY)
        case .middleRight:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.midY)
        case .bottomLeft:
            return CGPoint(x: cropFrame.minX, y: cropFrame.maxY)
        case .bottomCenter:
            return CGPoint(x: cropFrame.midX, y: cropFrame.maxY)
        case .bottomRight:
            return CGPoint(x: cropFrame.maxX, y: cropFrame.maxY)
        }
    }
    
    private func handleResize(handle: HandleType, translation: CGSize) {
        var newFrame = cropFrame
        
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
        
        // Apply constraints
        newFrame = constrainFrame(newFrame)
        cropFrame = newFrame
        
        updateCropCallback()
    }
    
    private func updateCropFrame() {
        // Update based on current drag and scale
        let scaledWidth = cropFrame.width * scale
        let scaledHeight = cropFrame.height * scale
        
        let newCenterX = cropFrame.midX + dragOffset.width
        let newCenterY = cropFrame.midY + dragOffset.height
        
        cropFrame = CGRect(
            x: newCenterX - scaledWidth / 2,
            y: newCenterY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )
        
        updateCropCallback()
    }
    
    private func constrainCropFrame() {
        cropFrame = constrainFrame(cropFrame)
        updateCropCallback()
    }
    
    private func constrainFrame(_ frame: CGRect) -> CGRect {
        var constrained = frame
        
        // Minimum size constraint
        let minSize: CGFloat = 20
        constrained.size.width = max(minSize, min(constrained.size.width, videoDisplayRect.width))
        constrained.size.height = max(minSize, min(constrained.size.height, videoDisplayRect.height))
        
        // Position constraints
        if constrained.minX < videoDisplayRect.minX {
            constrained.origin.x = videoDisplayRect.minX
        }
        if constrained.minY < videoDisplayRect.minY {
            constrained.origin.y = videoDisplayRect.minY
        }
        if constrained.maxX > videoDisplayRect.maxX {
            constrained.origin.x = videoDisplayRect.maxX - constrained.width
        }
        if constrained.maxY > videoDisplayRect.maxY {
            constrained.origin.y = videoDisplayRect.maxY - constrained.height
        }
        
        return constrained
    }
    
    private func updateCropCallback() {
        // Convert view coordinates to video coordinates
        guard !videoDisplayRect.isEmpty && videoSize.width > 0 && videoSize.height > 0 else { return }
        
        let relativeX = (cropFrame.origin.x - videoDisplayRect.origin.x) / videoDisplayRect.width
        let relativeY = (cropFrame.origin.y - videoDisplayRect.origin.y) / videoDisplayRect.height
        let relativeWidth = cropFrame.width / videoDisplayRect.width
        let relativeHeight = cropFrame.height / videoDisplayRect.height
        
        let videoCropRect = CGRect(
            x: relativeX * videoSize.width,
            y: relativeY * videoSize.height,
            width: relativeWidth * videoSize.width,
            height: relativeHeight * videoSize.height
        )
        
        cropRect = videoCropRect
        onCropChanged(videoCropRect)
    }
}

// MARK: - Preview
#Preview {
    SwiftUICropView(
        player: AVPlayer(),
        videoSize: CGSize(width: 1920, height: 1080),
        cropRect: .constant(CGRect(x: 100, y: 100, width: 200, height: 200)),
        aspectRatio: .free,
        showCropOverlay: true,
        onCropChanged: { _ in }
    )
    .frame(height: 400)
}