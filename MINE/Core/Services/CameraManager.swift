@preconcurrency import AVFoundation
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
    @Published var recordingTimeReachedLimit = false  // 5秒制限到達フラグ
    
    // MARK: - Recording Limits
    let freeVersionVideoLimit: TimeInterval = 5.0 // 5秒
    let proVersionVideoLimit: TimeInterval = 300.0 // 5分
    
    // MARK: - Private Properties
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoOutput: AVCaptureMovieFileOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var currentVideoURL: URL?
    private var recordingTimer: Timer?
    // PhotoCaptureDelegateを強い参照で保持するための辞書
    private var photoDelegates: [UUID: PhotoCaptureDelegate] = [:]
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
    
    func checkPermissionsAsync() async {
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
        Task { [weak self] in
            await self?.configureSession()
        }
    }
    
    private func configureSession() async {
        guard !session.isRunning else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        // 既存の入力・出力をクリア
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        // Video Input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            await MainActor.run {
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
            await MainActor.run {
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
        
        // Photo Output
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
        
        session.commitConfiguration()
        startSession()
    }
    
    // MARK: - Session Control
    func startSession() {
        Task { @MainActor in
            if !session.isRunning {
                let currentSession = session
                sessionQueue.async {
                    currentSession.startRunning()
                }
            }
        }
    }
    
    func stopSession() {
        Task { @MainActor in
            if session.isRunning {
                let currentSession = session
                sessionQueue.async {
                    currentSession.stopRunning()
                }
            }
        }
    }
    
    // MARK: - Recording Control
    func startRecording() {
        print("[CameraManager] startRecording called - isRecording: \(isRecording), permissionGranted: \(permissionGranted)")
        
        // 基本的な状態チェック
        guard !isRecording else {
            print("[CameraManager] Already recording")
            error = .recordingFailed("既に録画中です")
            return
        }
        
        guard permissionGranted else {
            print("[CameraManager] Permission not granted")
            error = .permissionDenied
            return
        }
        
        guard session.isRunning else {
            print("[CameraManager] Session not running")
            error = .sessionConfigurationFailed
            return
        }
        
        guard let output = videoOutput else {
            print("[CameraManager] VideoOutput is nil")
            error = .recordingFailed("録画出力が初期化されていません")
            return
        }
        
        // 出力が録画可能か確認
        guard !output.isRecording else {
            print("[CameraManager] Output already recording")
            error = .recordingFailed("録画出力が使用中です")
            return
        }
        
        // 録画ファイルのURL生成
        let fileName = "MINE_\(Date().timeIntervalSince1970).mp4"
        let recordsDirectory = Constants.Storage.recordsDirectory
        
        // ディレクトリが存在しない場合は作成
        do {
            try FileManager.default.createDirectory(at: recordsDirectory, withIntermediateDirectories: true)
        } catch {
            print("[CameraManager] Failed to create records directory: \(error)")
            self.error = .recordingFailed("保存ディレクトリの作成に失敗しました")
            return
        }
        
        currentVideoURL = recordsDirectory.appendingPathComponent(fileName)
        
        guard let url = currentVideoURL else {
            print("[CameraManager] Failed to create file URL")
            error = .recordingFailed("ファイルURLの生成に失敗しました")
            return
        }
        
        print("[CameraManager] Starting recording to: \(url.path)")
        
        // 既存ファイルがある場合は削除
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        
        // 録画開始
        output.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        recordingTime = 0
        recordingTimeReachedLimit = false  // フラグをリセット
        
        // タイマー開始
        startRecordingTimer()
        
        print("[CameraManager] Recording started successfully")
    }
    
    func stopRecording() {
        guard isRecording, let output = videoOutput else { return }
        
        output.stopRecording()
        isRecording = false
        recordingTimeReachedLimit = false  // フラグをリセット
        stopRecordingTimer()
    }
    
    // MARK: - Timer Management
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.recordingTime += 0.1
                
                // フリープランで5秒に達した場合はフラグを立てる（自動停止はしない）
                if !KeychainService.shared.isProVersion && self.recordingTime >= self.freeVersionVideoLimit {
                    if !self.recordingTimeReachedLimit {
                        self.recordingTimeReachedLimit = true
                    }
                }
                
                // プレミアムプランの最大時間に達したら自動停止
                if KeychainService.shared.isProVersion && self.recordingTime >= self.maxRecordingDuration {
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
    
    // MARK: - Memory Management
    deinit {
        // タイマーのクリーンアップ（同期）
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Photo delegatesのクリーンアップ（Main actorで実行）
        Task { @MainActor [photoDelegates] in
            _ = photoDelegates // 参照を保持してクリーンアップ
        }
        
        // セッションをバックグラウンドで安全にクリーンアップ
        let currentSession = session
        sessionQueue.async {
            if currentSession.isRunning {
                currentSession.stopRunning()
            }
            currentSession.inputs.forEach { currentSession.removeInput($0) }
            currentSession.outputs.forEach { currentSession.removeOutput($0) }
        }
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
    
    // MARK: - Photo Capture  
    func capturePhoto() async throws -> URL {
        guard let photoOutput = photoOutput else {
            throw CameraError.deviceNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let settings = AVCapturePhotoSettings()
            let delegateId = UUID()
            
            let delegate = PhotoCaptureDelegate(continuation: continuation) { completedDelegateId in
                // Main actorで実行してdelegateを辞書から削除
                Task { @MainActor [weak self] in
                    print("[CameraManager] Removing delegate \(completedDelegateId)")
                    self?.photoDelegates.removeValue(forKey: completedDelegateId)
                }
            }
            
            // Main actorでdelegateを強い参照で保持
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.photoDelegates[delegateId] = delegate
                print("[CameraManager] Starting photo capture with delegate \(delegateId)")
                print("[CameraManager] Active delegates: \(self.photoDelegates.count)")
                
                // メインアクター上でcapturePhotoを実行
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }
}

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let continuation: CheckedContinuation<URL, Error>
    private let completionHandler: (UUID) -> Void
    private let delegateId = UUID()
    
    init(continuation: CheckedContinuation<URL, Error>, completionHandler: @escaping (UUID) -> Void) {
        self.continuation = continuation
        self.completionHandler = completionHandler
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            // 完了時には必ずcompletionHandlerを呼び出してdelegateを解放
            completionHandler(delegateId)
        }
        
        if let error = error {
            print("[PhotoCaptureDelegate] Photo capture failed with error: \(error)")
            continuation.resume(throwing: error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("[PhotoCaptureDelegate] Failed to get image data")
            continuation.resume(throwing: CameraManager.CameraError.recordingFailed("画像データの取得に失敗しました"))
            return
        }
        
        // ファイルに保存（動画と同じディレクトリに保存）
        let filename = "MINE_photo_\(Date().timeIntervalSince1970).jpg"
        let recordsDirectory = Constants.Storage.recordsDirectory
        
        // ディレクトリが存在しない場合は作成
        do {
            try FileManager.default.createDirectory(at: recordsDirectory, withIntermediateDirectories: true)
            print("[PhotoCaptureDelegate] Created directory: \(recordsDirectory)")
        } catch {
            print("[PhotoCaptureDelegate] Failed to create directory: \(error)")
            continuation.resume(throwing: error)
            return
        }
        
        let fileURL = recordsDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            print("[PhotoCaptureDelegate] Successfully saved photo to: \(fileURL)")
            continuation.resume(returning: fileURL)
        } catch {
            print("[PhotoCaptureDelegate] Failed to save photo: \(error)")
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let videoRecordingCompleted = Notification.Name("videoRecordingCompleted")
    static let recordSaved = Notification.Name("recordSaved")
}