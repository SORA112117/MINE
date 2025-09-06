import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - Recording Error
enum RecordingError: LocalizedError {
    case noRecordedFile
    
    var errorDescription: String? {
        switch self {
        case .noRecordedFile:
            return "録画ファイルが見つかりません"
        }
    }
}


// MARK: - Recording ViewModel
@MainActor
class RecordingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showPermissionDenied = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var recordingCompleted = false
    @Published var savedCompleted = false  // 保存完了フラグ
    @Published var showVideoEditor = false
    @Published var recordedVideoURL: URL?
    @Published var currentRecordingTime: TimeInterval = 0  // 録画時間を直接管理
    @Published var showRecordingLimitDialog = false  // 5秒制限達成時のダイアログ表示
    
    // Presentation Mode for dismissing entire recording flow
    var presentationMode: Binding<PresentationMode>?
    
    // 遅延初期化に変更してクラッシュを防ぐ
    @Published var cameraManager: CameraManager?
    @Published var audioRecorderService: AudioRecorderService?
    
    // MARK: - Properties
    let recordType: RecordType
    private let createRecordUseCase: CreateRecordUseCase
    private let mediaService: MediaService
    private let manageTemplatesUseCase: ManageTemplatesUseCase
    private var cancellables = Set<AnyCancellable>()
    private var lastRecordedURL: URL?
    private var isInitialized = false
    
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
        
        // 初期化をasyncで実行
        Task {
            await initializeServicesAsync()
        }
    }
    
    // MARK: - Async Initialization
    @MainActor
    private func initializeServicesAsync() async {
        guard !isInitialized else { return }
        
        do {
            print("[RecordingViewModel] Starting async initialization for \(recordType)")
            
            // 必要なサービスのみを初期化
            switch recordType {
            case .video:
                self.cameraManager = CameraManager()
                // カメラマネージャーの初期化完了まで少し待つ
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                setupCameraBindings()
                
            case .audio:
                self.audioRecorderService = AudioRecorderService()
                // オーディオレコーダーの初期化完了まで少し待つ
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                setupAudioBindings()
                
            case .image:
                // 写真の場合はカメラのみ必要
                self.cameraManager = CameraManager()
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                setupCameraBindings()
            }
            
            setupNotifications()
            isInitialized = true
            
            print("[RecordingViewModel] Async initialization completed for \(recordType)")
            
        } catch {
            print("[RecordingViewModel] Initialization error: \(error)")
            errorMessage = "サービスの初期化に失敗しました"
        }
    }
    
    // MARK: - Setup
    private func setupCameraBindings() {
        guard let cameraManager = cameraManager else { return }
        
        // カメラマネージャーの権限状態を監視
        cameraManager.$permissionGranted
            .sink { [weak self] granted in
                if self?.recordType == .video || self?.recordType == .image {
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
        
        // 録画時間を監視（重要：これによりUIが更新される）
        cameraManager.$recordingTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentRecordingTime = time
            }
            .store(in: &cancellables)
        
        // 5秒制限到達フラグを監視
        cameraManager.$recordingTimeReachedLimit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reachedLimit in
                if reachedLimit {
                    self?.showRecordingLimitDialog = true
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioBindings() {
        guard let audioRecorderService = audioRecorderService else { return }
        
        // オーディオレコーダーの権限状態を監視
        audioRecorderService.$permissionGranted
            .sink { [weak self] granted in
                if self?.recordType == .audio {
                    self?.showPermissionDenied = !granted
                }
            }
            .store(in: &cancellables)
        
        // 録音時間を監視（UIの時間表示を更新）
        audioRecorderService.$recordingTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentRecordingTime = time
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
        // 初期化が完了していない場合は待つ
        guard isInitialized else {
            errorMessage = "サービスの初期化中です。しばらくお待ちください"
            return
        }
        
        // エラーメッセージをクリア
        errorMessage = nil
        
        switch recordType {
        case .video:
            startVideoRecording()
        case .audio:
            startAudioRecording()
        case .image:
            // 写真撮影実装（後で追加）
            errorMessage = "写真撮影機能は開発中です"
        }
    }
    
    private func startVideoRecording() {
        guard let cameraManager = cameraManager else {
            errorMessage = "カメラサービスが初期化されていません"
            return
        }
        
        // カメラ権限を再確認
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraStatus {
        case .authorized:
            // 権限ありの場合、カメラマネージャーの状態を確認
            if cameraManager.permissionGranted {
                // セッションが準備できているか確認
                if !cameraManager.isRecording {
                    print("[DEBUG] Starting video recording...")
                    cameraManager.startRecording()
                } else {
                    errorMessage = "既に録画中です"
                }
            } else {
                // カメラマネージャーの初期化を待つ
                errorMessage = "カメラの準備中です。しばらくお待ちください"
                // 1秒後に再試行
                Task {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    if cameraManager.permissionGranted {
                        cameraManager.startRecording()
                    } else {
                        await MainActor.run {
                            self.errorMessage = "カメラが利用できません"
                        }
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "カメラへのアクセスが拒否されています。設定で許可してください"
            showPermissionDenied = true
        case .notDetermined:
            // 権限を再要求
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    if granted {
                        cameraManager.checkPermissions()
                        // 少し待ってから録画開始
                        Task {
                            try await Task.sleep(nanoseconds: 500_000_000)
                            if cameraManager.permissionGranted {
                                cameraManager.startRecording()
                            }
                        }
                    } else {
                        self.errorMessage = "カメラの権限が必要です"
                        self.showPermissionDenied = true
                    }
                }
            }
        @unknown default:
            errorMessage = "カメラの権限状態が不明です"
        }
    }
    
    private func startAudioRecording() {
        guard let audioRecorderService = audioRecorderService else {
            errorMessage = "オーディオサービスが初期化されていません"
            return
        }
        
        let audioStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch audioStatus {
        case .granted:
            if audioRecorderService.permissionGranted {
                Task {
                    let success = await audioRecorderService.startRecording()
                    if !success {
                        await MainActor.run {
                            self.errorMessage = "録音の開始に失敗しました"
                        }
                    }
                }
            } else {
                errorMessage = "オーディオレコーダーの準備中です"
            }
        case .denied:
            errorMessage = "マイクへのアクセスが拒否されています。設定で許可してください"
            showPermissionDenied = true
        case .undetermined:
            // 権限を要求
            Task {
                let granted = await audioRecorderService.requestPermissionAsync()
                await MainActor.run {
                    if granted {
                        Task {
                            let success = await audioRecorderService.startRecording()
                            if !success {
                                await MainActor.run {
                                    self.errorMessage = "録音の開始に失敗しました"
                                }
                            }
                        }
                    } else {
                        self.errorMessage = "マイクの権限が必要です"
                        self.showPermissionDenied = true
                    }
                }
            }
        @unknown default:
            errorMessage = "マイクの権限状態が不明です"
        }
    }
    
    func stopRecording() {
        switch recordType {
        case .video:
            cameraManager?.stopRecording()
        case .audio:
            audioRecorderService?.stopRecording()
        case .image:
            // 写真の場合は即座に撮影
            break
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() {
        guard let cameraManager = cameraManager else {
            errorMessage = "カメラサービスが初期化されていません"
            return
        }
        
        guard cameraManager.permissionGranted else {
            errorMessage = "カメラの権限が必要です"
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                // 写真を撮影してファイルに保存
                let photoURL = try await cameraManager.capturePhoto()
                
                await MainActor.run {
                    self.recordedVideoURL = photoURL // 画像URLを保存
                    self.handlePhotoCompleted(url: photoURL)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "写真の撮影に失敗しました: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    // 写真撮影完了処理
    private func handlePhotoCompleted(url: URL) {
        lastRecordedURL = url
        recordedVideoURL = url
        isProcessing = false
        
        // 写真の場合はクロッピング編集が可能なので、メタデータ入力画面を先に表示
        recordingCompleted = true
    }
    
    // MARK: - Recording Completion
    private func handleRecordingCompleted(url: URL) {
        lastRecordedURL = url
        recordedVideoURL = url  // 編集画面用にURLを保存
        
        // 全ての記録タイプでメタデータ入力画面を先に表示
        // 編集は各メタデータ入力画面から実行可能
        recordingCompleted = true
    }
    
    // 編集後の保存処理
    func saveRecording(url: URL) {
        isProcessing = true
        
        Task {
            do {
                // Core Dataに保存（UseCaseが内部でサムネイル生成を行う）
                let duration = recordType == .video ? currentRecordingTime : (audioRecorderService?.recordingTime ?? 0)
                let _ = try await createRecordUseCase.execute(
                    type: recordType,
                    fileURL: url,
                    duration: duration,
                    title: "新しい記録",
                    tags: []
                )
                
                // 成功メッセージを表示
                showSuccessMessage = true
                
                // 2秒後に画面を閉じる
                try await Task.sleep(nanoseconds: 2_000_000_000)
                recordingCompleted = true
                
            } catch {
                errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            }
            
            isProcessing = false
        }
    }
    
    // メタデータ付きで保存（新規追加）
    func saveRecordingWithMetadata(recordData: RecordMetadata) {
        isProcessing = true
        
        Task {
            do {
                // 録画ファイルのURLを取得
                guard let url = recordedVideoURL else {
                    throw RecordingError.noRecordedFile
                }
                
                // 録画時間の計算
                let duration = recordType == .video ? currentRecordingTime : (audioRecorderService?.recordingTime ?? 0)
                
                // Core Dataにメタデータ付きで保存
                let _ = try await createRecordUseCase.execute(
                    type: recordType,
                    fileURL: url,
                    duration: duration,
                    title: recordData.title,
                    tags: recordData.tags
                )
                
                // 保存完了を通知
                savedCompleted = true
                
            } catch {
                errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            }
            
            isProcessing = false
        }
    }
    
    // デフォルト保存（キャンセル時用）
    func saveRecording() {
        guard let url = recordedVideoURL else {
            errorMessage = "録画ファイルが見つかりません"
            return
        }
        saveRecording(url: url)
    }
    
    // MARK: - 5秒制限ダイアログの選択肢
    
    /// 「このまま保存」を選択した場合
    func saveCurrentRecording() {
        showRecordingLimitDialog = false
        stopRecording() // 録画を停止してメタデータ入力画面に進む
    }
    
    /// 「撮影し直し」を選択した場合  
    func restartRecording() {
        showRecordingLimitDialog = false
        
        // 現在の録画を停止
        cameraManager?.stopRecording()
        
        // 少し待ってから録画を再開
        Task {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待機
            await MainActor.run {
                self.startRecording()
            }
        }
    }
    
    
    // MARK: - Camera Lifecycle
    func startCameraSession() {
        print("[RecordingViewModel] startCameraSession called - isInitialized: \(isInitialized), recordType: \(recordType)")
        
        // 初期化されていない場合は非同期で初期化を待つ
        if !isInitialized {
            print("[RecordingViewModel] Not initialized, starting initialization...")
            Task {
                await initializeServicesAsync()
                await MainActor.run {
                    self.startCameraSession()
                }
            }
            return
        }
        
        guard let cameraManager = cameraManager else {
            print("[RecordingViewModel] CameraManager is nil")
            return
        }
        
        if recordType == .video || recordType == .image {
            print("[RecordingViewModel] Starting camera session")
            
            // 非同期で権限チェックとセッション開始
            Task {
                await cameraManager.checkPermissionsAsync()
                await MainActor.run {
                    print("[RecordingViewModel] Permission granted: \(cameraManager.permissionGranted)")
                    if cameraManager.permissionGranted {
                        cameraManager.startSession()
                    } else {
                        self.showPermissionDenied = true
                    }
                }
            }
        }
    }
    
    func stopCameraSession() {
        guard let cameraManager = cameraManager else { return }
        
        if recordType == .video || recordType == .image {
            print("[RecordingViewModel] Stopping camera session")
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            }
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Computed Properties
    var isRecording: Bool {
        switch recordType {
        case .video:
            return cameraManager?.isRecording ?? false
        case .audio:
            return audioRecorderService?.isRecording ?? false
        case .image:
            return false
        }
    }
    
    var recordingTime: TimeInterval {
        switch recordType {
        case .video:
            return cameraManager?.recordingTime ?? 0
        case .audio:
            return audioRecorderService?.recordingTime ?? 0
        case .image:
            return 0
        }
    }
    
    var maxRecordingTime: TimeInterval {
        let isPro = KeychainService.shared.isProVersion
        switch recordType {
        case .video:
            guard let cameraManager = cameraManager else { return isPro ? 300.0 : 5.0 }
            return isPro ? cameraManager.proVersionVideoLimit : cameraManager.freeVersionVideoLimit
        case .audio:
            guard let audioRecorderService = audioRecorderService else { return isPro ? .infinity : 90.0 }
            return isPro ? audioRecorderService.proVersionAudioLimit : audioRecorderService.freeVersionAudioLimit
        case .image:
            return 0
        }
    }
    
    var formattedRecordingTime: String {
        switch recordType {
        case .video:
            let totalSeconds = Int(currentRecordingTime)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            let milliseconds = Int((currentRecordingTime.truncatingRemainder(dividingBy: 1)) * 10)
            return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
        case .audio:
            return audioRecorderService?.formattedRecordingTime ?? "00:00.0"
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
            return audioRecorderService?.formattedMaxTime ?? "00:00"
        case .image:
            return "00:00"
        }
    }
    
    // MARK: - Data Management
    func discardRecording() {
        print("[RecordingViewModel] Discarding recorded data")
        
        // 記録されたファイルがあれば削除
        if let url = lastRecordedURL {
            Task {
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                        print("[RecordingViewModel] Deleted file: \(url.path)")
                    }
                } catch {
                    print("[RecordingViewModel] Failed to delete file: \(error)")
                }
                
                await MainActor.run {
                    self.lastRecordedURL = nil
                    self.recordedVideoURL = nil
                }
            }
        }
        
        // 状態をリセット
        recordingCompleted = false
        savedCompleted = false
        isProcessing = false
    }
    
    // MARK: - Cleanup
    deinit {
        // deinitでMainActorメソッドは呼び出せないため、
        // カメラセッションの停止はonDisappearで行う
        cancellables.removeAll()
    }
}