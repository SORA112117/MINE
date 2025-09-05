import Foundation
import AVFoundation
import SwiftUI
import Combine

// MARK: - Video Editor ViewModel
@MainActor
class VideoEditorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var editParameters = VideoEditParameters()
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0
    @Published var error: String?
    @Published var showError = false
    @Published var currentPlaybackTime: CMTime = .zero
    @Published var isPlaying = false
    @Published var previewMode: VideoPreviewMode = .edited
    @Published var currentOperation: VideoEditOperation = .trim
    
    // トリミング用
    @Published var trimStartPosition: Double = 0
    @Published var trimEndPosition: Double = 1
    
    // クロッピング用
    @Published var cropAspectRatio: CropAspectRatio = .free
    @Published var cropRect: CGRect = .zero
    @Published var showCropOverlay = false
    
    // MARK: - Properties
    let originalVideoURL: URL
    private var editorService: VideoEditorService?
    private var cancellables = Set<AnyCancellable>()
    var player: AVPlayer?  // VideoPlayerで使用するためpublicに変更
    private var playerObserver: Any?
    
    // MARK: - Computed Properties
    var videoDuration: Double {
        editorService?.videoDuration.seconds ?? 0
    }
    
    var trimmedDuration: Double {
        (trimEndPosition - trimStartPosition) * videoDuration
    }
    
    var formattedTrimmedDuration: String {
        let seconds = Int(trimmedDuration)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    
    var formattedCurrentTime: String {
        let seconds = Int(currentPlaybackTime.seconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    
    var canSave: Bool {
        // フリープランでは5秒まで
        let isPro = KeychainService.shared.isProVersion
        let maxDuration = isPro ? 300.0 : 5.0
        return trimmedDuration > 0 && trimmedDuration <= maxDuration && !isProcessing
    }
    
    var isOverFreePlanLimit: Bool {
        let isPro = KeychainService.shared.isProVersion
        return !isPro && trimmedDuration > 5.0
    }
    
    // MARK: - Initialization
    init(videoURL: URL) {
        self.originalVideoURL = videoURL
        
        Task {
            await setupEditor()
        }
    }
    
    // MARK: - Setup
    private func setupEditor() async {
        do {
            editorService = try VideoEditorService(videoURL: originalVideoURL)
            
            // 初期パラメータを設定
            if let duration = editorService?.videoDuration {
                editParameters.trimStartTime = .zero
                editParameters.trimEndTime = duration
            }
            
            // プレイヤーをセットアップ
            setupPlayer()
            
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
    
    // MARK: - Player Setup
    private func setupPlayer() {
        player = AVPlayer(url: originalVideoURL)
        
        // プレイバック時間を監視
        let interval = CMTime(seconds: 0.01, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        playerObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.currentPlaybackTime = time
            
            // トリミング範囲外になったらループ
            if let self = self {
                let endTime = self.editParameters.trimEndTime
                if time >= endTime {
                    self.player?.seek(to: self.editParameters.trimStartTime)
                }
            }
        }
    }
    
    // MARK: - Playback Control
    func play() {
        guard let player = player else { return }
        
        // トリミング開始位置から再生
        player.seek(to: editParameters.trimStartTime)
        player.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to position: Double) {
        guard let duration = editorService?.videoDuration else { return }
        let time = CMTime(seconds: position * duration.seconds, preferredTimescale: duration.timescale)
        player?.seek(to: time)
    }
    
    // MARK: - Trimming
    func updateTrimRange() {
        guard let duration = editorService?.videoDuration else { return }
        
        editParameters.trimStartTime = CMTime(
            seconds: trimStartPosition * duration.seconds,
            preferredTimescale: duration.timescale
        )
        
        editParameters.trimEndTime = CMTime(
            seconds: trimEndPosition * duration.seconds,
            preferredTimescale: duration.timescale
        )
        
        // プレイヤーの再生範囲を更新
        if currentPlaybackTime < editParameters.trimStartTime || 
           currentPlaybackTime > editParameters.trimEndTime {
            player?.seek(to: editParameters.trimStartTime)
        }
    }
    
    // MARK: - Cropping
    func updateCropRect(_ rect: CGRect) {
        cropRect = rect
        editParameters.cropRect = rect
    }
    
    func resetCrop() {
        cropRect = .zero
        editParameters.cropRect = nil
        showCropOverlay = false
    }
    
    func applyCropAspectRatio(_ ratio: CropAspectRatio) {
        guard let videoSize = editorService?.videoSize else { return }
        
        cropAspectRatio = ratio
        
        switch ratio {
        case .free:
            // フリークロップの場合は何もしない
            break
            
        case .square:
            let size = min(videoSize.width, videoSize.height)
            let x = (videoSize.width - size) / 2
            let y = (videoSize.height - size) / 2
            updateCropRect(CGRect(x: x, y: y, width: size, height: size))
            
        case .portrait:
            let targetRatio: CGFloat = 9.0 / 16.0
            let width = min(videoSize.width, videoSize.height * targetRatio)
            let height = width / targetRatio
            let x = (videoSize.width - width) / 2
            let y = (videoSize.height - height) / 2
            updateCropRect(CGRect(x: x, y: y, width: width, height: height))
            
        case .landscape:
            let targetRatio: CGFloat = 16.0 / 9.0
            let height = min(videoSize.height, videoSize.width / targetRatio)
            let width = height * targetRatio
            let x = (videoSize.width - width) / 2
            let y = (videoSize.height - height) / 2
            updateCropRect(CGRect(x: x, y: y, width: width, height: height))
        }
        
        showCropOverlay = true
    }
    
    // MARK: - Save
    func saveEditedVideo(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let editorService = editorService else {
            completion(.failure(VideoEditorError.assetNotFound))
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                // 出力URLを生成
                let fileName = "MINE_edited_\(Date().timeIntervalSince1970).mp4"
                let outputURL = Constants.Storage.recordsDirectory.appendingPathComponent(fileName)
                
                // ディレクトリが存在しない場合は作成
                try FileManager.default.createDirectory(
                    at: Constants.Storage.recordsDirectory,
                    withIntermediateDirectories: true
                )
                
                // 編集した動画をエクスポート
                let resultURL = try await editorService.exportEditedVideo(
                    with: editParameters,
                    outputURL: outputURL,
                    quality: .high
                )
                
                await MainActor.run {
                    isProcessing = false
                    completion(.success(resultURL))
                }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = error.localizedDescription
                    self.showError = true
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Cleanup
    deinit {
        if let playerObserver = playerObserver {
            player?.removeTimeObserver(playerObserver)
        }
        player?.pause()
        player = nil
    }
}

// MARK: - Crop Aspect Ratio
enum CropAspectRatio: String, CaseIterable {
    case free = "フリー"
    case square = "正方形"
    case portrait = "縦長 (9:16)"
    case landscape = "横長 (16:9)"
    
    var displayName: String {
        return self.rawValue
    }
    
    var ratio: CGFloat? {
        switch self {
        case .free:
            return nil
        case .square:
            return 1.0
        case .portrait:
            return 9.0 / 16.0
        case .landscape:
            return 16.0 / 9.0
        }
    }
}