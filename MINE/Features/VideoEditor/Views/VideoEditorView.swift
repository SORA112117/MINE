import SwiftUI
import AVKit

// MARK: - Video Editor View
struct VideoEditorView: View {
    @StateObject private var viewModel: VideoEditorViewModel
    @Environment(\.dismiss) private var dismiss
    let onSave: (URL) -> Void
    
    init(videoURL: URL, onSave: @escaping (URL) -> Void) {
        _viewModel = StateObject(wrappedValue: VideoEditorViewModel(videoURL: videoURL))
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ナビゲーションバー
                navigationBar
                
                // ビデオプレビュー
                videoPreview
                    .overlay(alignment: .bottom) {
                        if viewModel.showCropOverlay {
                            cropOverlay
                        }
                    }
                
                // 編集コントロール
                editingControls
                
                // 保存ボタン
                saveButton
            }
            
            // 処理中オーバーレイ
            if viewModel.isProcessing {
                processingOverlay
            }
        }
        .alert("エラー", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.error ?? "不明なエラーが発生しました")
        }
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button("キャンセル") {
                dismiss()
            }
            .foregroundColor(.white)
            
            Spacer()
            
            Text("編集")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            // プレミアムプラン案内（フリープランで5秒超過時）
            if viewModel.isOverFreePlanLimit {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("5秒まで")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("プレミアムで無制限")
                        .font(.caption2)
                        .foregroundColor(.yellow.opacity(0.8))
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Video Preview
    private var videoPreview: some View {
        GeometryReader { geometry in
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .disabled(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .overlay(alignment: .bottom) {
                        // 再生コントロール
                        playbackControls
                            .padding()
                    }
            } else {
                // プレイヤーが初期化されていない場合
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        ProgressView("動画を読み込み中...")
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        HStack {
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            
            Text(viewModel.formattedCurrentTime)
                .font(.caption)
                .foregroundColor(.white)
                .monospacedDigit()
            
            Slider(
                value: Binding(
                    get: { viewModel.currentPlaybackTime.seconds / viewModel.videoDuration },
                    set: { viewModel.seek(to: $0) }
                ),
                in: 0...1
            )
            .accentColor(.white)
            
            Text(viewModel.formattedTrimmedDuration)
                .font(.caption)
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Crop Overlay
    private var cropOverlay: some View {
        GeometryReader { geometry in
            let rect = viewModel.cropRect
            
            // 半透明の黒でマスク
            Color.black.opacity(0.5)
                .overlay(
                    Rectangle()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
            
            // クロップ枠
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .overlay(
                    // グリッドライン
                    GridLinesView()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                )
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Editing Controls
    private var editingControls: some View {
        VStack(spacing: 0) {
            // 編集モード選択
            Picker("編集モード", selection: $viewModel.currentOperation) {
                Text("トリム").tag(VideoEditOperation.trim)
                Text("クロップ").tag(VideoEditOperation.crop)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .background(Color.black.opacity(0.8))
            
            // 各編集モードのコントロール
            switch viewModel.currentOperation {
            case .trim:
                trimControls
            case .crop:
                cropControls
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Trim Controls
    private var trimControls: some View {
        VStack(spacing: 16) {
            // タイムライン
            VideoTrimmerView(
                startPosition: $viewModel.trimStartPosition,
                endPosition: $viewModel.trimEndPosition,
                duration: viewModel.videoDuration,
                videoURL: viewModel.originalVideoURL
            )
            .frame(height: 60)
            .onChange(of: viewModel.trimStartPosition) { _ in
                viewModel.updateTrimRange()
            }
            .onChange(of: viewModel.trimEndPosition) { _ in
                viewModel.updateTrimRange()
            }
            
            // トリミング後の長さ表示
            HStack {
                Text("長さ: \(viewModel.formattedTrimmedDuration)")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                if viewModel.isOverFreePlanLimit {
                    Text("⚠️ 5秒を超えています")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Crop Controls
    private var cropControls: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(CropAspectRatio.allCases, id: \.self) { ratio in
                        Button(action: {
                            viewModel.applyCropAspectRatio(ratio)
                        }) {
                            Text(ratio.displayName)
                                .font(.caption)
                                .foregroundColor(viewModel.cropAspectRatio == ratio ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(viewModel.cropAspectRatio == ratio ? Color.white : Color.white.opacity(0.2))
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            if viewModel.showCropOverlay {
                Button("リセット") {
                    viewModel.resetCrop()
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: save) {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark")
                }
                
                Text(viewModel.isProcessing ? "処理中..." : "保存")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.canSave ? Theme.primary : Color.gray.opacity(0.5))
            )
        }
        .disabled(!viewModel.canSave)
        .padding()
    }
    
    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("動画を処理中...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: viewModel.processingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .frame(width: 200)
                
                Text("\(Int(viewModel.processingProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
            )
        }
    }
    
    // MARK: - Actions
    private func save() {
        viewModel.saveEditedVideo { result in
            switch result {
            case .success(let url):
                onSave(url)
                dismiss()
            case .failure(let error):
                viewModel.error = error.localizedDescription
                viewModel.showError = true
            }
        }
    }
}

// MARK: - Grid Lines View
struct GridLinesView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // 縦線
                let thirdWidth = geometry.size.width / 3
                for i in 1..<3 {
                    path.move(to: CGPoint(x: thirdWidth * CGFloat(i), y: 0))
                    path.addLine(to: CGPoint(x: thirdWidth * CGFloat(i), y: geometry.size.height))
                }
                
                // 横線
                let thirdHeight = geometry.size.height / 3
                for i in 1..<3 {
                    path.move(to: CGPoint(x: 0, y: thirdHeight * CGFloat(i)))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: thirdHeight * CGFloat(i)))
                }
            }
            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
    }
}

// MARK: - Video Trimmer View (簡易版)
struct VideoTrimmerView: View {
    @Binding var startPosition: Double
    @Binding var endPosition: Double
    let duration: Double
    let videoURL: URL
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                
                // 選択範囲
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .frame(
                        width: (endPosition - startPosition) * geometry.size.width,
                        height: geometry.size.height
                    )
                    .position(
                        x: (startPosition + (endPosition - startPosition) / 2) * geometry.size.width,
                        y: geometry.size.height / 2
                    )
                
                // 開始ハンドル
                trimHandle(isStart: true)
                    .position(
                        x: startPosition * geometry.size.width,
                        y: geometry.size.height / 2
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = max(0, min(value.location.x / geometry.size.width, endPosition - 0.01))
                                startPosition = newPosition
                            }
                    )
                
                // 終了ハンドル
                trimHandle(isStart: false)
                    .position(
                        x: endPosition * geometry.size.width,
                        y: geometry.size.height / 2
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPosition = max(startPosition + 0.01, min(value.location.x / geometry.size.width, 1))
                                endPosition = newPosition
                            }
                    )
            }
        }
    }
    
    private func trimHandle(isStart: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 10, height: 50)
            .overlay(
                Image(systemName: isStart ? "chevron.left" : "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.black)
            )
    }
}