import SwiftUI

// MARK: - Interactive Crop View
struct InteractiveCropView: View {
    @Binding var cropRect: CGRect
    let videoSize: CGSize
    let aspectRatio: CropAspectRatio
    let onCropChanged: (CGRect) -> Void
    
    @State private var isDragging = false
    @State private var isResizing = false
    @State private var lastPanLocation: CGPoint = .zero
    @State private var resizeHandle: ResizeHandle?
    
    // 最小クロップサイズ
    private let minCropSize: CGSize = CGSize(width: 50, height: 50)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景のオーバーレイ（暗くする部分）
                backgroundOverlay(geometry: geometry)
                
                // クロップ枠
                cropFrame(geometry: geometry)
                
                // リサイズハンドル
                resizeHandles(geometry: geometry)
            }
        }
        .onAppear {
            initializeCropRect()
        }
        .onChange(of: aspectRatio) { _ in
            applyCropAspectRatio()
        }
        .onChange(of: videoSize) { _ in
            initializeCropRect()
        }
    }
    
    // MARK: - Background Overlay
    private func backgroundOverlay(geometry: GeometryProxy) -> some View {
        Color.black.opacity(0.5)
            .overlay(
                Rectangle()
                    .frame(
                        width: cropRect.width * geometry.size.width / videoSize.width,
                        height: cropRect.height * geometry.size.height / videoSize.height
                    )
                    .position(
                        x: (cropRect.midX / videoSize.width) * geometry.size.width,
                        y: (cropRect.midY / videoSize.height) * geometry.size.height
                    )
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }
    
    // MARK: - Crop Frame
    private func cropFrame(geometry: GeometryProxy) -> some View {
        let frameWidth = cropRect.width * geometry.size.width / videoSize.width
        let frameHeight = cropRect.height * geometry.size.height / videoSize.height
        let frameX = (cropRect.midX / videoSize.width) * geometry.size.width
        let frameY = (cropRect.midY / videoSize.height) * geometry.size.height
        
        return ZStack {
            // メインのクロップ枠
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: frameWidth, height: frameHeight)
                .position(x: frameX, y: frameY)
            
            // グリッドライン
            gridLines(width: frameWidth, height: frameHeight)
                .position(x: frameX, y: frameY)
            
            // 中央移動用の透明エリア
            Rectangle()
                .fill(Color.clear)
                .frame(width: frameWidth, height: frameHeight)
                .position(x: frameX, y: frameY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            moveCropRect(
                                translation: value.translation,
                                geometry: geometry
                            )
                        }
                )
        }
    }
    
    // MARK: - Grid Lines
    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            // 縦線
            let thirdWidth = width / 3
            for i in 1..<3 {
                path.move(to: CGPoint(x: thirdWidth * CGFloat(i) - width/2, y: -height/2))
                path.addLine(to: CGPoint(x: thirdWidth * CGFloat(i) - width/2, y: height/2))
            }
            
            // 横線
            let thirdHeight = height / 3
            for i in 1..<3 {
                path.move(to: CGPoint(x: -width/2, y: thirdHeight * CGFloat(i) - height/2))
                path.addLine(to: CGPoint(x: width/2, y: thirdHeight * CGFloat(i) - height/2))
            }
        }
        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
    }
    
    // MARK: - Resize Handles
    private func resizeHandles(geometry: GeometryProxy) -> some View {
        let frameWidth = cropRect.width * geometry.size.width / videoSize.width
        let frameHeight = cropRect.height * geometry.size.height / videoSize.height
        let frameX = (cropRect.midX / videoSize.width) * geometry.size.width
        let frameY = (cropRect.midY / videoSize.height) * geometry.size.height
        
        return ZStack {
            // 四隅のリサイズハンドル
            ForEach(ResizeHandle.allCases, id: \.self) { handle in
                resizeHandle(handle)
                    .position(
                        x: frameX + handle.offset.x * frameWidth / 2,
                        y: frameY + handle.offset.y * frameHeight / 2
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                resizeCropRect(
                                    handle: handle,
                                    translation: value.translation,
                                    geometry: geometry
                                )
                            }
                    )
            }
        }
    }
    
    // MARK: - Resize Handle
    private func resizeHandle(_ handle: ResizeHandle) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 2)
    }
    
    // MARK: - Gesture Handlers
    
    private func moveCropRect(translation: CGSize, geometry: GeometryProxy) {
        let videoScaleX = videoSize.width / geometry.size.width
        let videoScaleY = videoSize.height / geometry.size.height
        
        let deltaX = translation.width * videoScaleX
        let deltaY = translation.height * videoScaleY
        
        var newRect = cropRect
        newRect.origin.x += deltaX
        newRect.origin.y += deltaY
        
        // 境界内に収める
        newRect.origin.x = max(0, min(newRect.origin.x, videoSize.width - newRect.width))
        newRect.origin.y = max(0, min(newRect.origin.y, videoSize.height - newRect.height))
        
        cropRect = newRect
        onCropChanged(newRect)
    }
    
    private func resizeCropRect(handle: ResizeHandle, translation: CGSize, geometry: GeometryProxy) {
        let videoScaleX = videoSize.width / geometry.size.width
        let videoScaleY = videoSize.height / geometry.size.height
        
        let deltaX = translation.width * videoScaleX
        let deltaY = translation.height * videoScaleY
        
        var newRect = cropRect
        
        switch handle {
        case .topLeft:
            let maxDeltaX = min(deltaX, newRect.width - minCropSize.width)
            let maxDeltaY = min(deltaY, newRect.height - minCropSize.height)
            newRect.origin.x += maxDeltaX
            newRect.origin.y += maxDeltaY
            newRect.size.width -= maxDeltaX
            newRect.size.height -= maxDeltaY
            
        case .topRight:
            let maxDeltaX = max(deltaX, minCropSize.width - newRect.width)
            let maxDeltaY = min(deltaY, newRect.height - minCropSize.height)
            newRect.origin.y += maxDeltaY
            newRect.size.width += maxDeltaX
            newRect.size.height -= maxDeltaY
            
        case .bottomLeft:
            let maxDeltaX = min(deltaX, newRect.width - minCropSize.width)
            let maxDeltaY = max(deltaY, minCropSize.height - newRect.height)
            newRect.origin.x += maxDeltaX
            newRect.size.width -= maxDeltaX
            newRect.size.height += maxDeltaY
            
        case .bottomRight:
            let maxDeltaX = max(deltaX, minCropSize.width - newRect.width)
            let maxDeltaY = max(deltaY, minCropSize.height - newRect.height)
            newRect.size.width += maxDeltaX
            newRect.size.height += maxDeltaY
        }
        
        // アスペクト比を維持する場合
        if aspectRatio != .free, let ratio = aspectRatio.ratio {
            let currentRatio = newRect.width / newRect.height
            if currentRatio != ratio {
                // 幅基準でアスペクト比を調整
                newRect.size.height = newRect.width / ratio
                
                // 高さが最小値を下回る場合は高さ基準で調整
                if newRect.height < minCropSize.height {
                    newRect.size.height = minCropSize.height
                    newRect.size.width = newRect.height * ratio
                }
            }
        }
        
        // 境界チェック
        newRect.origin.x = max(0, newRect.origin.x)
        newRect.origin.y = max(0, newRect.origin.y)
        
        if newRect.maxX > videoSize.width {
            newRect.origin.x = videoSize.width - newRect.width
        }
        if newRect.maxY > videoSize.height {
            newRect.origin.y = videoSize.height - newRect.height
        }
        
        cropRect = newRect
        onCropChanged(newRect)
    }
    
    // MARK: - Helper Methods
    
    private func initializeCropRect() {
        guard cropRect == .zero else { return }
        
        // デフォルトのクロップ範囲（中央80%）
        let margin = min(videoSize.width, videoSize.height) * 0.1
        cropRect = CGRect(
            x: margin,
            y: margin,
            width: videoSize.width - margin * 2,
            height: videoSize.height - margin * 2
        )
        onCropChanged(cropRect)
    }
    
    private func applyCropAspectRatio() {
        guard let ratio = aspectRatio.ratio else {
            return // フリーの場合は何もしない
        }
        
        let currentRatio = cropRect.width / cropRect.height
        
        if currentRatio != ratio {
            var newRect = cropRect
            
            // 現在の中心を保持
            let centerX = newRect.midX
            let centerY = newRect.midY
            
            // 幅基準でアスペクト比を調整
            newRect.size.height = newRect.width / ratio
            
            // 高さが動画サイズを超える場合は高さ基準で調整
            if newRect.height > videoSize.height {
                newRect.size.height = videoSize.height - 20
                newRect.size.width = newRect.height * ratio
            }
            
            // 中心を再調整
            newRect.origin.x = centerX - newRect.width / 2
            newRect.origin.y = centerY - newRect.height / 2
            
            // 境界内に収める
            newRect.origin.x = max(0, min(newRect.origin.x, videoSize.width - newRect.width))
            newRect.origin.y = max(0, min(newRect.origin.y, videoSize.height - newRect.height))
            
            cropRect = newRect
            onCropChanged(newRect)
        }
    }
}

// MARK: - Resize Handle Enum
enum ResizeHandle: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    
    var offset: CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: -1, y: -1)
        case .topRight: return CGPoint(x: 1, y: -1)
        case .bottomLeft: return CGPoint(x: -1, y: 1)
        case .bottomRight: return CGPoint(x: 1, y: 1)
        }
    }
}