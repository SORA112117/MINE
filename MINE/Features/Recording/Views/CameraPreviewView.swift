import SwiftUI
import AVFoundation

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        // カメラプレビューレイヤーを設定
        let previewLayer = cameraManager.previewLayer()
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        // Auto Layoutを設定
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // プレビューレイヤーのフレームを更新
        if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // クリーンアップ（必要に応じて）
        uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
}

// MARK: - Recording Controls View
struct RecordingControlsView: View {
    @ObservedObject var cameraManager: CameraManager
    let onComplete: (URL) -> Void
    
    private var recordingTimeText: String {
        let totalSeconds = Int(cameraManager.recordingTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((cameraManager.recordingTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
    
    private var maxTimeText: String {
        let isPro = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion)
        let maxTime = isPro ? cameraManager.proVersionVideoLimit : cameraManager.freeVersionVideoLimit
        let totalSeconds = Int(maxTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var timeRemainingText: String {
        let isPro = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion)
        let maxTime = isPro ? cameraManager.proVersionVideoLimit : cameraManager.freeVersionVideoLimit
        let remaining = max(0, maxTime - cameraManager.recordingTime)
        let totalSeconds = Int(remaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack {
            // 録画時間表示
            if cameraManager.isRecording {
                HStack {
                    // 録画中インジケーター
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 4)
                                .scaleEffect(cameraManager.isRecording ? 2 : 1)
                                .opacity(cameraManager.isRecording ? 0 : 1)
                                .animation(
                                    Animation.easeOut(duration: 1)
                                        .repeatForever(autoreverses: false),
                                    value: cameraManager.isRecording
                                )
                        )
                    
                    Text(recordingTimeText)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("/")
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(maxTimeText)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
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
                .padding(.top, 50)
            }
            
            Spacer()
            
            // 録画ボタン
            HStack(spacing: 60) {
                // フラッシュボタン（将来実装）
                Button(action: {
                    // フラッシュ切り替え
                }) {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .opacity(0.5) // 未実装のため半透明
                
                // 録画開始/停止ボタン
                Button(action: {
                    if cameraManager.isRecording {
                        cameraManager.stopRecording()
                    } else {
                        cameraManager.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 80, height: 80)
                        
                        if cameraManager.isRecording {
                            // 停止ボタン（四角）
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                                .frame(width: 35, height: 35)
                        } else {
                            // 録画ボタン（赤い円）
                            Circle()
                                .fill(Color.red)
                                .frame(width: 65, height: 65)
                        }
                    }
                }
                
                // カメラ切り替えボタン（将来実装）
                Button(action: {
                    // カメラ切り替え
                }) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .opacity(0.5) // 未実装のため半透明
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Permission Denied View
struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.gray4)
            
            Text("カメラへのアクセスが必要です")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            Text("MINEで動画を記録するには、設定からカメラへのアクセスを許可してください")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.gray5)
                .padding(.horizontal, 40)
            
            Button(action: {
                // 設定アプリを開く
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }) {
                Text("設定を開く")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Theme.primary)
                    .cornerRadius(Constants.UI.cornerRadius)
            }
            .padding(.top, 10)
        }
        .padding()
    }
}