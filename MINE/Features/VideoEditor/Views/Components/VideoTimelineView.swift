import SwiftUI
import AVFoundation
import UIKit

// MARK: - Video Timeline View
struct VideoTimelineView: View {
    @Binding var startPosition: Double
    @Binding var endPosition: Double
    let videoURL: URL
    let duration: Double
    let onPositionChanged: () -> Void
    
    @State private var thumbnails: [UIImage] = []
    @State private var isGeneratingThumbnails = false
    private let thumbnailCount = 6
    
    var body: some View {
        VStack(spacing: 12) {
            // タイムライン本体
            timelineBody
            
            // 時間ラベル
            timeLabels
        }
        .onAppear {
            generateThumbnails()
        }
    }
    
    // MARK: - Timeline Body
    private var timelineBody: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景とサムネイル
                timelineBackground(geometry: geometry)
                
                // 選択範囲のオーバーレイ
                selectionOverlay(geometry: geometry)
                
                // トリミングハンドル
                trimmingHandles(geometry: geometry)
            }
        }
        .frame(height: 60)
        .clipped()
    }
    
    // MARK: - Timeline Background
    private func timelineBackground(geometry: GeometryProxy) -> some View {
        HStack(spacing: 1) {
            if thumbnails.isEmpty {
                // サムネイル生成中またはエラー時
                ForEach(0..<thumbnailCount, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Group {
                                if isGeneratingThumbnails {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.5)
                                } else {
                                    Image(systemName: "video")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        )
                }
            } else {
                // サムネイルを表示
                ForEach(0..<thumbnails.count, id: \.self) { index in
                    Image(uiImage: thumbnails[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width / CGFloat(thumbnailCount), height: 60)
                        .clipped()
                }
            }
        }
        .background(Color.black)
        .cornerRadius(8)
    }
    
    // MARK: - Selection Overlay
    private func selectionOverlay(geometry: GeometryProxy) -> some View {
        let startX = startPosition * geometry.size.width
        let endX = endPosition * geometry.size.width
        let selectionWidth = endX - startX
        
        return ZStack {
            // 選択範囲外を暗くする
            HStack(spacing: 0) {
                // 左側のマスク
                if startX > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: startX)
                }
                
                // 選択範囲（透明）
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: selectionWidth)
                
                // 右側のマスク
                if endX < geometry.size.width {
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: geometry.size.width - endX)
                }
            }
            
            // 選択範囲の境界線
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: selectionWidth, height: 60)
                .position(x: startX + selectionWidth / 2, y: 30)
        }
    }
    
    // MARK: - Trimming Handles
    private func trimmingHandles(geometry: GeometryProxy) -> some View {
        ZStack {
            // 開始ハンドル
            trimHandle(isStart: true)
                .position(x: startPosition * geometry.size.width, y: 30)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newPosition = max(0, min(value.location.x / geometry.size.width, endPosition - 0.02))
                            startPosition = newPosition
                            onPositionChanged()
                        }
                )
            
            // 終了ハンドル
            trimHandle(isStart: false)
                .position(x: endPosition * geometry.size.width, y: 30)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newPosition = max(startPosition + 0.02, min(value.location.x / geometry.size.width, 1))
                            endPosition = newPosition
                            onPositionChanged()
                        }
                )
        }
    }
    
    // MARK: - Trim Handle
    private func trimHandle(isStart: Bool) -> some View {
        ZStack {
            // ハンドルの背景
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 20, height: 60)
                .shadow(color: .black.opacity(0.3), radius: 2)
            
            // ハンドルのグリップライン
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 2, height: 12)
                }
            }
            
            // 方向指示アイコン
            Image(systemName: isStart ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
                .font(.caption2)
                .foregroundColor(.blue)
                .offset(x: isStart ? -8 : 8, y: -25)
        }
    }
    
    // MARK: - Time Labels
    private var timeLabels: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("開始")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(formatTime(startPosition * duration))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("長さ")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(formatTime((endPosition - startPosition) * duration))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("終了")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(formatTime(endPosition * duration))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, remainingSeconds, milliseconds)
    }
    
    private func generateThumbnails() {
        guard !isGeneratingThumbnails else { return }
        
        isGeneratingThumbnails = true
        
        Task {
            do {
                let asset = AVAsset(url: videoURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.maximumSize = CGSize(width: 120, height: 67) // 16:9 ratio
                imageGenerator.requestedTimeToleranceAfter = .zero
                imageGenerator.requestedTimeToleranceBefore = .zero
                
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                var generatedThumbnails: [UIImage] = []
                
                for i in 0..<thumbnailCount {
                    let timeInterval = (durationSeconds / Double(thumbnailCount)) * Double(i)
                    let time = CMTime(seconds: timeInterval, preferredTimescale: 600)
                    
                    do {
                        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                        let uiImage = UIImage(cgImage: cgImage)
                        generatedThumbnails.append(uiImage)
                    } catch {
                        print("Failed to generate thumbnail at time \(timeInterval): \(error)")
                        // フォールバックとして灰色のプレースホルダーを作成
                        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 67))
                        let fallbackImage = renderer.image { context in
                            UIColor.gray.setFill()
                            context.fill(CGRect(origin: .zero, size: CGSize(width: 120, height: 67)))
                        }
                        generatedThumbnails.append(fallbackImage)
                    }
                }
                
                await MainActor.run {
                    self.thumbnails = generatedThumbnails
                    self.isGeneratingThumbnails = false
                }
                
            } catch {
                print("Failed to generate thumbnails: \(error)")
                await MainActor.run {
                    self.isGeneratingThumbnails = false
                }
            }
        }
    }
}