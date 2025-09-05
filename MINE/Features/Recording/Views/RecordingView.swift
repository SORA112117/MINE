import SwiftUI
import AVFoundation

struct RecordingView: View {
    @StateObject var viewModel: RecordingViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var showingVideoEditor = false
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.ignoresSafeArea()
            
            // コンテンツ
            if viewModel.recordType == .video {
                // ビデオ録画UI
                videoRecordingView
            } else {
                // オーディオ/写真UI（プレースホルダー）
                placeholderRecordingView
            }
            
            // エラーメッセージ
            if let errorMessage = viewModel.errorMessage {
                errorOverlay(message: errorMessage)
            }
            
            // 成功メッセージ
            if viewModel.showSuccessMessage {
                successOverlay
            }
            
            // 処理中インジケーター
            if viewModel.isProcessing {
                processingOverlay
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startCameraSession()
        }
        .onDisappear {
            viewModel.stopCameraSession()
        }
        .onChange(of: viewModel.showVideoEditor) { show in
            if show {
                showingVideoEditor = true
            }
        }
        .onChange(of: viewModel.recordingCompleted) { completed in
            if completed {
                dismiss()
            }
        }
        .sheet(isPresented: $showingVideoEditor) {
            if let videoURL = viewModel.recordedVideoURL {
                VideoEditorView(videoURL: videoURL) { editedURL in
                    viewModel.saveRecording(url: editedURL)
                }
            }
        }
    }
    
    // MARK: - Video Recording View
    private var videoRecordingView: some View {
        ZStack {
            // カメラプレビュー
            if let cameraManager = viewModel.cameraManager, cameraManager.permissionGranted {
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                // 録画コントロール
                VStack {
                    // 上部のコントロール
                    topControls
                    
                    Spacer()
                    
                    // 録画ボタンと時間表示
                    recordingControls
                }
            } else if viewModel.showPermissionDenied {
                // 権限拒否画面
                permissionDeniedView
            } else {
                // ローディング
                ProgressView("カメラを準備中...")
                    .foregroundColor(.white)
            }
        }
    }
    
    // MARK: - Top Controls
    private var topControls: some View {
        HStack {
            // キャンセルボタン
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                }
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            
            Spacer()
            
            // 録画時間表示
            if viewModel.isRecording {
                recordingTimeDisplay
            }
            
            Spacer()
            
            // 設定ボタン（将来実装）
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .opacity(0.3) // 未実装
            .disabled(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }
    
    // MARK: - Recording Time Display
    private var recordingTimeDisplay: some View {
        VStack(spacing: 4) {
            // 録画時間表示
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 3)
                            .scaleEffect(viewModel.isRecording ? 2 : 1)
                            .opacity(viewModel.isRecording ? 0 : 1)
                            .animation(
                                Animation.easeOut(duration: 1)
                                    .repeatForever(autoreverses: false),
                                value: viewModel.isRecording
                            )
                    )
                
                Text(viewModel.formattedRecordingTime)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // プレミアムプラン案内（フリープランの場合）
            if !KeychainService.shared.isProVersion {
                Text("5秒まで / プレミアムでより長く録画")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Recording Controls
    private var recordingControls: some View {
        VStack(spacing: 30) {
            // 中央の録画ボタン（iPhone純正風）
            HStack(spacing: 60) {
                // 空のスペーサー（左側）
                Color.clear
                    .frame(width: 60, height: 60)
                
                // 録画ボタン
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }) {
                    ZStack {
                        // 外側の白い円
                        Circle()
                            .stroke(Color.white, lineWidth: 5)
                            .frame(width: 75, height: 75)
                        
                        // 内側の赤い部分
                        if viewModel.isRecording {
                            // 録画中は角丸の正方形
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.red)
                                .frame(width: 30, height: 30)
                                .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                        } else {
                            // 待機中は円
                            Circle()
                                .fill(Color.red)
                                .frame(width: 60, height: 60)
                                .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                        }
                    }
                }
                .disabled(viewModel.isProcessing)
                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                
                // カメラ切り替えボタン
                Button(action: {}) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .opacity(0.5)
                .disabled(true)
            }
            
            // 下部のオプションボタン
            HStack(spacing: 40) {
                // フラッシュボタン
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.slash")
                            .font(.system(size: 20))
                        Text("オフ")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                .disabled(true)
                
                // エフェクトボタン（将来実装）
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                        Text("エフェクト")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                .disabled(true)
                
                // 設定ボタン（将来実装）
                Button(action: {}) {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                        Text("設定")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                .disabled(true)
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Placeholder Recording View
    private var placeholderRecordingView: some View {
        VStack(spacing: Constants.UI.padding) {
            Text("\(viewModel.recordType.displayName)を記録")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("この機能は開発中です")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
            
            // プレースホルダーエリア
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .fill(Color.white.opacity(0.1))
                .frame(height: 300)
                .overlay(
                    VStack {
                        Image(systemName: viewModel.recordType.systemImage)
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("\(viewModel.recordType.displayName)記録エリア")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top)
                    }
                )
                .padding()
            
            // キャンセルボタン
            Button(action: { dismiss() }) {
                Text("閉じる")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(Theme.primary)
                    .cornerRadius(Constants.UI.cornerRadius)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Error Overlay
    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                
                Text(message)
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.9))
            )
            .padding()
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: viewModel.errorMessage)
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("保存完了！")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("記録が正常に保存されました")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.9))
            )
        }
        .transition(.opacity)
        .animation(.easeInOut, value: viewModel.showSuccessMessage)
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
                
                Text("保存中...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.9))
            )
        }
    }
    
    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "video.slash")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                Text("カメラへのアクセスが必要です")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("ビデオを録画するためにカメラの権限が必要です。設定から権限を許可してください。")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                // 設定アプリを開くボタン
                Button(action: {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("設定を開く")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Theme.primary)
                    .cornerRadius(12)
                }
                
                // キャンセルボタン
                Button(action: {
                    dismiss()
                }) {
                    Text("キャンセル")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}