import AVFoundation
import Combine
import Foundation

// MARK: - Audio Recorder Service
@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var permissionGranted = false
    @Published var error: AudioRecorderError?
    @Published var audioLevels: [Float] = []
    
    // MARK: - Recording Limits
    let freeVersionAudioLimit: TimeInterval = 90.0 // 1分30秒
    let proVersionAudioLimit: TimeInterval = .infinity // 無制限
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var audioSession = AVAudioSession.sharedInstance()
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var currentRecordingURL: URL?
    
    private var maxRecordingDuration: TimeInterval {
        KeychainService.shared.isProVersion 
            ? proVersionAudioLimit : freeVersionAudioLimit
    }
    
    // MARK: - Audio Recorder Error Types
    enum AudioRecorderError: LocalizedError {
        case permissionDenied
        case sessionConfigurationFailed
        case recordingFailed(String)
        case audioEngineError(String)
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "マイクへのアクセスが拒否されています"
            case .sessionConfigurationFailed:
                return "オーディオセッションの設定に失敗しました"
            case .recordingFailed(let reason):
                return "録音に失敗しました: \(reason)"
            case .audioEngineError(let reason):
                return "オーディオエンジンエラー: \(reason)"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        Task { @MainActor in
            await checkPermissionsAsync()
        }
    }
    
    // MARK: - Permission Management
    func checkPermissions() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                permissionGranted = true
                setupAudioSession()
            case .undetermined:
                requestPermission()
            case .denied:
                permissionGranted = false
                error = .permissionDenied
            @unknown default:
                permissionGranted = false
                error = .permissionDenied
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                permissionGranted = true
                setupAudioSession()
            case .undetermined:
                requestPermission()
            case .denied:
                permissionGranted = false
                error = .permissionDenied
            @unknown default:
                permissionGranted = false
                error = .permissionDenied
            }
        }
    }
    
    private func checkPermissionsAsync() async {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                permissionGranted = true
                setupAudioSession()
            case .undetermined:
                await requestPermissionAsync()
            case .denied:
                permissionGranted = false
                error = .permissionDenied
            @unknown default:
                permissionGranted = false
                error = .permissionDenied
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                permissionGranted = true
                setupAudioSession()
            case .undetermined:
                await requestPermissionAsync()
            case .denied:
                permissionGranted = false
                error = .permissionDenied
            @unknown default:
                permissionGranted = false
                error = .permissionDenied
            }
        }
    }
    
    private func requestPermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupAudioSession()
                    } else {
                        self?.error = .permissionDenied
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupAudioSession()
                    } else {
                        self?.error = .permissionDenied
                    }
                }
            }
        }
    }
    
    func requestPermissionAsync() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        
        permissionGranted = granted
        if granted {
            setupAudioSession()
        } else {
            error = .permissionDenied
        }
        
        return granted
    }
    
    // MARK: - Audio Session Configuration
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            self.error = .sessionConfigurationFailed
        }
    }
    
    // MARK: - Recording Control
    func startRecording() async -> Bool {
        guard !isRecording, permissionGranted else { return false }
        
        // 録音ファイルのURL生成
        let fileName = "MINE_audio_\(Date().timeIntervalSince1970).m4a"
        let documentsPath = Constants.Storage.recordsDirectory
        currentRecordingURL = documentsPath.appendingPathComponent(fileName)
        
        guard let url = currentRecordingURL else { return false }
        
        // 録音設定
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Constants.MediaQuality.audioSampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: Constants.MediaQuality.audioBitrate
        ]
        
        do {
            // レコーダー作成
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // 録音開始
            if audioRecorder?.record() == true {
                isRecording = true
                recordingTime = 0
                startRecordingTimer()
                startLevelMonitoring()
                return true
            } else {
                error = .recordingFailed("録音の開始に失敗しました")
                return false
            }
        } catch {
            self.error = .recordingFailed(error.localizedDescription)
            return false
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        isRecording = false
        stopRecordingTimer()
        stopLevelMonitoring()
        
        // オーディオセッション非アクティブ化
        try? audioSession.setActive(false)
    }
    
    func pauseRecording() {
        guard isRecording else { return }
        audioRecorder?.pause()
        stopRecordingTimer()
        stopLevelMonitoring()
    }
    
    func resumeRecording() {
        guard !isRecording, audioRecorder != nil else { return }
        
        if audioRecorder?.record() == true {
            isRecording = true
            startRecordingTimer()
            startLevelMonitoring()
        }
    }
    
    // MARK: - Timer Management
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.recordingTime += 0.1
                
                // 最大録音時間に達したら自動停止
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
    
    // MARK: - Audio Level Monitoring
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAudioLevels()
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevels.removeAll()
    }
    
    private func updateAudioLevels() {
        audioRecorder?.updateMeters()
        
        guard let recorder = audioRecorder else { return }
        
        let power = recorder.averagePower(forChannel: 0)
        let level = min(max((power + 50.0) / 50.0, 0.0), 1.0) // -50db to 0db -> 0.0 to 1.0
        
        // 波形データの管理（最大100ポイント）
        audioLevels.append(level)
        if audioLevels.count > 100 {
            audioLevels.removeFirst()
        }
    }
    
    // MARK: - Computed Properties
    var formattedRecordingTime: String {
        let totalSeconds = Int(recordingTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((recordingTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
    
    var formattedMaxTime: String {
        if maxRecordingDuration == .infinity {
            return "∞"
        }
        let totalSeconds = Int(maxRecordingDuration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var recordingProgress: Double {
        guard maxRecordingDuration != .infinity else { return 0.0 }
        return min(recordingTime / maxRecordingDuration, 1.0)
    }
    
    // MARK: - Memory Management & Cleanup
    deinit {
        // レコーダーを安全に停止
        audioRecorder?.stop()
        audioRecorder = nil
        
        // タイマーを確実に停止（同期的に）
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        
        // オーディオセッションをバックグラウンドでクリーンアップ
        DispatchQueue.global(qos: .background).async { [audioSession] in
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to deactivate audio session in deinit: \(error)")
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                // 録音成功 - URLを通知
                if let url = self.currentRecordingURL {
                    NotificationCenter.default.post(
                        name: .audioRecordingCompleted,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
            } else {
                self.error = .recordingFailed("録音の保存に失敗しました")
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = .recordingFailed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let audioRecordingCompleted = Notification.Name("audioRecordingCompleted")
}