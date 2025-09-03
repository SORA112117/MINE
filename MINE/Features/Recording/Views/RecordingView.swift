import SwiftUI
import AVFoundation

struct RecordingView: View {
    @StateObject var viewModel: RecordingViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
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
        .onChange(of: viewModel.recordingCompleted) { completed in
            if completed {
                dismiss()
            }
        }
    }
    
    // MARK: - Video Recording View
    private var videoRecordingView: some View {
        ZStack {
            // カメラプレビュー
            if viewModel.cameraManager.permissionGranted {
                CameraPreviewView(cameraManager: viewModel.cameraManager)
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
                PermissionDeniedView()
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
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            
            Text("/")
                .foregroundColor(.white.opacity(0.5))
            
            Text(viewModel.formattedMaxTime)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Recording Controls
    private var recordingControls: some View {
        HStack(spacing: 50) {
            // フラッシュボタン
            Button(action: {}) {
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .opacity(0.3)
            .disabled(true)
            
            // 録画ボタン
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 85, height: 85)
                    
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 35, height: 35)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                    }
                }
            }
            .disabled(viewModel.isProcessing)
            
            // カメラ切り替えボタン
            Button(action: {}) {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .opacity(0.3)
            .disabled(true)
        }
        .padding(.bottom, 50)
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
}