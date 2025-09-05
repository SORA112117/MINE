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
        .onAppear {
            // 編集画面の初期設定
            viewModel.setupInitialState()
        }
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        ZStack {
            // 中央のタイトル（固定位置）
            Text("編集")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                // 左側のキャンセルボタン
                Button("キャンセル") {
                    dismiss()
                }
                .foregroundColor(.white)
                
                Spacer()
                
                // 右側のプレミアム案内（固定幅で配置）
                Group {
                    if viewModel.isOverFreePlanLimit {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("5秒まで")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text("プレミアムで無制限")
                                .font(.caption2)
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                    } else {
                        // 空のスペース（レイアウト維持のため）
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 80, height: 1)
                    }
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
                VideoPlayerCropView(
                    player: player,
                    cropRect: $viewModel.cropRect,
                    videoSize: viewModel.editorService?.videoSize ?? .zero,
                    aspectRatio: viewModel.cropAspectRatio,
                    showCropOverlay: viewModel.currentOperation == .crop && viewModel.showCropOverlay,
                    onCropChanged: { rect in
                        viewModel.updateCropRect(rect)
                    }
                )
                .overlay(alignment: .bottom) {
                    // 再生コントロール（クロップ時は非表示）
                    if viewModel.currentOperation != .crop || !viewModel.showCropOverlay {
                        playbackControls
                            .padding()
                    }
                }
            } else {
                // プレイヤーが初期化されていない場合
                Rectangle()
                    .fill(Color.black)
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            
                            Text("動画を読み込み中...")
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                    )
            }
        }
    }
    
    // MARK: - Playback Controls
    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formattedCurrentTime)
                    .font(.caption)
                    .foregroundColor(.white)
                    .monospacedDigit()
                
                // プレイバック位置スライダー
                Slider(
                    value: Binding(
                        get: {
                            guard viewModel.videoDuration > 0 else { return 0 }
                            return viewModel.currentPlaybackTime.seconds / viewModel.videoDuration
                        },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...1
                )
                .accentColor(.white)
                .frame(width: 200)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("編集後")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(viewModel.formattedTrimmedDuration)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
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
            // 高品質タイムライン
            VideoTimelineView(
                startPosition: $viewModel.trimStartPosition,
                endPosition: $viewModel.trimEndPosition,
                videoURL: viewModel.originalVideoURL,
                duration: viewModel.videoDuration,
                onPositionChanged: {
                    viewModel.updateTrimRange()
                }
            )
            .frame(height: 100)
            
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
        VStack(spacing: 20) {
            // アスペクト比選択
            VStack(spacing: 12) {
                Text("アスペクト比")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(CropAspectRatio.allCases, id: \.self) { ratio in
                            cropAspectButton(for: ratio)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // クロップ操作説明
            VStack(spacing: 8) {
                Text("操作方法")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 16) {
                    instructionItem(icon: "hand.draw", text: "ドラッグして移動")
                    instructionItem(icon: "arrow.up.left.and.arrow.down.right", text: "角をドラッグしてサイズ調整")
                }
            }
            
            // アクションボタン
            HStack(spacing: 16) {
                Button("リセット") {
                    viewModel.resetCrop()
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                
                Button(viewModel.showCropOverlay ? "編集完了" : "クロップ開始") {
                    if viewModel.showCropOverlay {
                        // クロップ編集完了 - 現在の設定を確実に保存
                        viewModel.finalizeCropEditing()
                    } else {
                        // クロップ開始
                        viewModel.applyCropAspectRatio(viewModel.cropAspectRatio)
                    }
                    viewModel.showCropOverlay.toggle()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.9))
    }
    
    private func cropAspectButton(for ratio: CropAspectRatio) -> some View {
        Button(action: {
            viewModel.applyCropAspectRatio(ratio)
        }) {
            VStack(spacing: 6) {
                Rectangle()
                    .fill(viewModel.cropAspectRatio == ratio ? Color.white : Color.white.opacity(0.3))
                    .frame(
                        width: ratio == .portrait ? 20 : (ratio == .landscape ? 32 : 24),
                        height: ratio == .portrait ? 32 : (ratio == .landscape ? 20 : 24)
                    )
                    .overlay(
                        Rectangle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                
                Text(ratio.displayName)
                    .font(.caption2)
                    .foregroundColor(viewModel.cropAspectRatio == ratio ? .white : .white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.cropAspectRatio == ratio ? Color.white.opacity(0.2) : Color.clear)
            )
        }
    }
    
    private func instructionItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
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


