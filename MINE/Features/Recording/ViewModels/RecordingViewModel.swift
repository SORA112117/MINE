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
        
        // エラー監視
        cameraManager.$error
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
    }
    
    // MARK: - Recording Management
    func startRecording() {
        switch recordType {
        case .video:
            if cameraManager.permissionGranted {
                cameraManager.startRecording()
            }
        case .audio:
            // オーディオ録音実装（後で追加）
            print("Audio recording not yet implemented")
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
            // オーディオ録音停止実装
            break
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
                let record = try await createRecordUseCase.execute(
                    type: recordType,
                    fileURL: url,
                    duration: cameraManager.recordingTime,
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
        cameraManager.isRecording
    }
    
    var recordingTime: TimeInterval {
        cameraManager.recordingTime
    }
    
    var maxRecordingTime: TimeInterval {
        let isPro = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion)
        return isPro ? cameraManager.proVersionVideoLimit : cameraManager.freeVersionVideoLimit
    }
    
    var formattedRecordingTime: String {
        let totalSeconds = Int(recordingTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((recordingTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
    
    var formattedMaxTime: String {
        let totalSeconds = Int(maxRecordingTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Cleanup
    deinit {
        // deinitでMainActorメソッドは呼び出せないため、
        // カメラセッションの停止はonDisappearで行う
        cancellables.removeAll()
    }
}