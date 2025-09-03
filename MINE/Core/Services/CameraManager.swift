import AVFoundation
import UIKit
import Combine

// MARK: - Camera Manager
@MainActor
class CameraManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var permissionGranted = false
    @Published var error: CameraError?
    
    // MARK: - Recording Limits
    let freeVersionVideoLimit: TimeInterval = 5.0 // 5秒
    let proVersionVideoLimit: TimeInterval = 300.0 // 5分
    
    // MARK: - Private Properties
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentVideoURL: URL?
    private var recordingTimer: Timer?
    private var maxRecordingDuration: TimeInterval {
        KeychainService.shared.isProVersion ? proVersionVideoLimit : freeVersionVideoLimit
    }
    
    // MARK: - Camera Error Types
    enum CameraError: LocalizedError {
        case permissionDenied
        case sessionConfigurationFailed
        case deviceNotAvailable
        case recordingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "カメラへのアクセスが拒否されています"
            case .sessionConfigurationFailed:
                return "カメラの設定に失敗しました"
            case .deviceNotAvailable:
                return "カメラが利用できません"
            case .recordingFailed(let reason):
                return "録画に失敗しました: \(reason)"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        // 初期化後に非同期で権限チェック
        Task { @MainActor in
            await checkPermissionsAsync()
        }
    }
    
    // MARK: - Permission Management
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
            error = .permissionDenied
        }
    }
    
    private func checkPermissionsAsync() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            await requestPermissionAsync()
        default:
            permissionGranted = false
            error = .permissionDenied
        }
    }
    
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.permissionGranted = granted
                if granted {
                    self?.setupSession()
                } else {
                    self?.error = .permissionDenied
                }
            }
        }
    }
    
    private func requestPermissionAsync() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        permissionGranted = granted
        if granted {
            setupSession()
        } else {
            error = .permissionDenied
        }
    }
    
    // MARK: - Session Configuration
    private func setupSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        guard !session.isRunning else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // 既存の入力・出力をクリア
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        // Video Input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            Task { @MainActor in
                self.error = .deviceNotAvailable
            }
            session.commitConfiguration()
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
        } catch {
            Task { @MainActor in
                self.error = .sessionConfigurationFailed
            }
            session.commitConfiguration()
            return
        }
        
        // Audio Input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                print("Failed to add audio input: \(error)")
                // オーディオは必須ではないため、続行
            }
        }
        
        // Movie Output
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.videoOutput = movieOutput
            
            // 最大録画時間を設定
            let maxDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 600)
            movieOutput.maxRecordedDuration = maxDuration
        }
        
        session.commitConfiguration()
        startSession()
    }
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async { [weak self] in
            if !(self?.session.isRunning ?? false) {
                self?.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            if self?.session.isRunning ?? false {
                self?.session.stopRunning()
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() {
        guard !isRecording, let output = videoOutput else { return }
        
        // 録画ファイルのURL生成
        let fileName = "MINE_\(Date().timeIntervalSince1970).mp4"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        currentVideoURL = documentsPath.appendingPathComponent(fileName)
        
        guard let url = currentVideoURL else { return }
        
        // 録画開始
        output.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        recordingTime = 0
        
        // タイマー開始
        startRecordingTimer()
    }
    
    func stopRecording() {
        guard isRecording, let output = videoOutput else { return }
        
        output.stopRecording()
        isRecording = false
        stopRecordingTimer()
    }
    
    // MARK: - Timer Management
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.recordingTime += 0.1
                
                // 最大録画時間に達したら自動停止
                if self.recordingTime >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Preview Layer
    func previewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = .recordingFailed(error.localizedDescription)
            } else {
                // 録画成功 - URLを通知
                NotificationCenter.default.post(
                    name: .videoRecordingCompleted,
                    object: nil,
                    userInfo: ["url": outputFileURL]
                )
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let videoRecordingCompleted = Notification.Name("videoRecordingCompleted")
}