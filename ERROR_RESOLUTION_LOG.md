# Error Resolution Log

## 2025年9月3日 - RecordingViewModel初期化クラッシュ修正

### 問題概要
ホームタブから「動画で撮影」ボタンを押すと、アプリがクラッシュする問題が発生。

### エラー詳細
- **症状**: MainTabView → RecordingView遷移時にクラッシュ
- **原因**: RecordingViewModelの初期化処理で、CameraManagerとAudioRecorderServiceを同期的に初期化していたため、MainActor上でデッドロックが発生

### 根本原因分析
1. RecordingViewModelのinit()メソッド内で：
   ```swift
   self.cameraManager = CameraManager()
   self.audioRecorderService = AudioRecorderService()
   ```
2. CameraManagerとAudioRecorderServiceは、init()内で非同期のpermissionチェックを実行
3. これらがMainActor上で同期的に実行され、デッドロックやクラッシュの原因となった

### 解決策
RecordingViewModelを遅延初期化パターンに変更：

#### 1. プロパティをオプショナルに変更
```swift
@Published var cameraManager: CameraManager?
@Published var audioRecorderService: AudioRecorderService?
private var isInitialized = false
```

#### 2. 非同期初期化メソッドを追加
```swift
@MainActor
private func initializeServicesAsync() async {
    switch recordType {
    case .video:
        self.cameraManager = CameraManager()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        setupCameraBindings()
    case .audio:
        self.audioRecorderService = AudioRecorderService()
        try await Task.sleep(nanoseconds: 100_000_000)
        setupAudioBindings()
    // ...
    }
    isInitialized = true
}
```

#### 3. 初期化完了チェックを追加
```swift
func startRecording() {
    guard isInitialized else {
        errorMessage = "サービスの初期化中です。しばらくお待ちください"
        return
    }
    // ...
}
```

#### 4. RecordingViewも対応修正
```swift
// 修正前（クラッシュの原因）
if viewModel.cameraManager.permissionGranted {

// 修正後（安全なアクセス）
if let cameraManager = viewModel.cameraManager, cameraManager.permissionGranted {
```

### 効果
- ホームタブからの動画撮影画面への遷移が安全に実行できるようになった
- 必要なサービスのみを初期化することで、メモリ効率も改善
- 初期化中のユーザーフィードバックも追加

### 予防策
1. MainActor上でのサービス初期化は避ける
2. 重いオブジェクトの初期化は遅延実行を検討
3. オプショナルプロパティに対する安全なアクセスパターンを使用
4. 初期化状態の明確な管理

### 関連ファイル
- `MINE/Features/Recording/ViewModels/RecordingViewModel.swift`
- `MINE/Features/Recording/Views/RecordingView.swift`

### 学習ポイント
- SwiftUIでの@MainActor使用時の注意点
- 依存性注入における初期化タイミングの重要性
- 遅延初期化パターンの適用
- オプショナル型による安全なアクセス管理

---

## 2025年9月3日 - TCC Privacy Violation対応済み

### 問題概要
カメラとマイクの権限要求時にTCC Privacy Violationによるクラッシュが発生。

### 解決策
Info.plistにプライバシー使用説明を追加し、project.pbxprojのINFOPLIST_KEY_*形式を使用。

### 追加したプライバシー権限
- `INFOPLIST_KEY_NSCameraUsageDescription`
- `INFOPLIST_KEY_NSMicrophoneUsageDescription`

### 関連ファイル
- `MINE.xcodeproj/project.pbxproj`

---

## 2025年9月3日 - iOS 17.0+ API compatibility対応済み

### 問題概要
AudioRecorderServiceでiOS 17.0+のAVAudioApplication APIを使用していたが、後方互換性の問題があった。

### 解決策
```swift
if #available(iOS 17.0, *) {
    // iOS 17.0以降のAVAudioApplication API使用
    switch AVAudioApplication.shared.recordPermission {
} else {
    // iOS 16以前のAVAudioSession API使用
    switch AVAudioSession.sharedInstance().recordPermission {
}
```

### 関連ファイル
- `MINE/Core/Services/AudioRecorderService.swift`