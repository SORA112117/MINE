import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Recording ViewModel
@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showPermissionDenied = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var recordingCompleted = false
    @Published var cameraManager: CameraManager
    @Published var audioRecorderService: AudioRecorderService
    
    // MARK: - Properties
    let recordType: RecordType
    private let createRecordUseCase: CreateRecordUseCase
    private let mediaService: MediaService
    private let manageTemplatesUseCase: ManageTemplatesUseCase
    private var cancellables = Set<AnyCancellable>()
    private var lastRecordedURL: URL?
    
    // MARK: - Initialization
    init(
        recordType: RecordType,
        createRecordUseCase: CreateRecordUseCase,
        mediaService: MediaService,
        manageTemplatesUseCase: ManageTemplatesUseCase
    ) {
        self.recordType = recordType
        self.createRecordUseCase = createRecordUseCase
        self.mediaService = mediaService
        self.manageTemplatesUseCase = manageTemplatesUseCase
        self.cameraManager = CameraManager()
        self.audioRecorderService = AudioRecorderService()
        
        setupBindings()
        setupNotifications()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // カメラマネージャーの権限状態を監視
        cameraManager.$permissionGranted
            .sink { [weak self] granted in
                self?.showPermissionDenied = !granted && self?.recordType == .video
            }
            .store(in: &cancellables)
        
        // オーディオレコーダーの権限状態を監視
        audioRecorderService.$permissionGranted
            .sink { [weak self] granted in
                if self?.recordType == .audio {
                    self?.showPermissionDenied = !granted
                }
            }
            .store(in: &cancellables)
        
        // エラー監視（カメラ）
        cameraManager.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
            .store(in: &cancellables)
        
        // エラー監視（オーディオ）
        audioRecorderService.$error
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
            .store(in: &cancellables)
    }
    
    private func setupNotifications() {
        // 録画完了通知を監視
        NotificationCenter.default.publisher(for: .videoRecordingCompleted)
            .compactMap { $0.userInfo?["url"] as? URL }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.handleRecordingCompleted(url: url)
            }
            .store(in: &cancellables)
        
        // 録音完了通知を監視
        NotificationCenter.default.publisher(for: .audioRecordingCompleted)
            .compactMap { $0.userInfo?["url"] as? URL }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.handleRecordingCompleted(url: url)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Recording Management
    func startRecording() {
        switch recordType {
        case .video:
            if cameraManager.permissionGranted {
                cameraManager.startRecording()
            }
        case .audio:
            if audioRecorderService.permissionGranted {
                Task {
                    let success = await audioRecorderService.startRecording()
                    if !success {
                        errorMessage = "録音の開始に失敗しました"
                    }
                }
            }
        case .image:
            // 写真撮影実装（後で追加）
            print("Photo capture not yet implemented")
        }
    }
    
    func stopRecording() {
        switch recordType {
        case .video:
            cameraManager.stopRecording()
        case .audio:
            audioRecorderService.stopRecording()
        case .image:
            // 写真の場合は即座に撮影
            break
        }
    }
    
    // MARK: - Recording Completion
    private func handleRecordingCompleted(url: URL) {
        lastRecordedURL = url
        isProcessing = true
        
        Task {
            do {
                // Core Dataに保存（UseCaseが内部でサムネイル生成を行う）
                let duration = recordType == .video ? cameraManager.recordingTime : audioRecorderService.recordingTime
                let record = try await createRecordUseCase.execute(
                    type: recordType,
                    fileURL: url,
                    duration: duration,
                    comment: nil,
                    tags: [],
                    folderId: nil
                )
                
                // 成功メッセージを表示
                showSuccessMessage = true
                recordingCompleted = true
                
                // 2秒後に画面を閉じる
                try await Task.sleep(nanoseconds: 2_000_000_000)
                recordingCompleted = true
                
            } catch {
                errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            }
            
            isProcessing = false
        }
    }
    
    
    // MARK: - Camera Lifecycle
    func startCameraSession() {
        if recordType == .video {
            cameraManager.startSession()
        }
    }
    
    func stopCameraSession() {
        if recordType == .video {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Computed Properties
    var isRecording: Bool {
        switch recordType {
        case .video:
            return cameraManager.isRecording
        case .audio:
            return audioRecorderService.isRecording
        case .image:
            return false
        }
    }
    
    var recordingTime: TimeInterval {
        switch recordType {
        case .video:
            return cameraManager.recordingTime
        case .audio:
            return audioRecorderService.recordingTime
        case .image:
            return 0
        }
    }
    
    var maxRecordingTime: TimeInterval {
        let isPro = KeychainService.shared.isProVersion
        switch recordType {
        case .video:
            return isPro ? cameraManager.proVersionVideoLimit : cameraManager.freeVersionVideoLimit
        case .audio:
            return isPro ? audioRecorderService.proVersionAudioLimit : audioRecorderService.freeVersionAudioLimit
        case .image:
            return 0
        }
    }
    
    var formattedRecordingTime: String {
        switch recordType {
        case .video:
            let totalSeconds = Int(recordingTime)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            let milliseconds = Int((recordingTime.truncatingRemainder(dividingBy: 1)) * 10)
            return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
        case .audio:
            return audioRecorderService.formattedRecordingTime
        case .image:
            return "00:00.0"
        }
    }
    
    var formattedMaxTime: String {
        switch recordType {
        case .video:
            let totalSeconds = Int(maxRecordingTime)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
        case .audio:
            return audioRecorderService.formattedMaxTime
        case .image:
            return "00:00"
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // deinitでMainActorメソッドは呼び出せないため、
        // カメラセッションの停止はonDisappearで行う
        cancellables.removeAll()
    }
}