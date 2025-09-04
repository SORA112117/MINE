# Development Lessons Learned - MINE Project

## 概要
MINEプロジェクトの開発で得た技術的知見、ベストプラクティス、アーキテクチャパターンをまとめたドキュメントです。将来の開発効率向上と品質担保のために活用してください。

---

## 🏗️ Architecture Patterns

### MVVM + Clean Architecture Implementation

**学んだこと:**
- ViewModelの責務分離による保守性向上
- Use Casesによるビジネスロジックの抽象化
- Dependency Injectionによるテスタビリティ向上

**実装例:**
```swift
// ViewModel: UIロジックのみ担当
@MainActor
class RecordingViewModel: ObservableObject {
    private let createRecordUseCase: CreateRecordUseCase
    private let mediaService: MediaService
    
    init(createRecordUseCase: CreateRecordUseCase, mediaService: MediaService) {
        self.createRecordUseCase = createRecordUseCase
        self.mediaService = mediaService
    }
}

// Use Case: ビジネスロジック担当
class CreateRecordUseCase {
    private let recordRepository: RecordRepositoryProtocol
    private let mediaService: MediaServiceProtocol
    
    func execute(type: RecordType, fileURL: URL, duration: TimeInterval) async throws -> Record {
        // ビジネスルール実装
    }
}
```

**教訓:**
- 各層の責務を明確に分離する
- protocolによる依存関係の抽象化
- テスト容易性を考慮した設計

### Service Layer Design

**パターン1: Platform Service (CameraManager, AudioRecorderService)**
```swift
@MainActor
class CameraManager: NSObject, ObservableObject {
    // プラットフォーム固有の機能をラップ
    // UIの状態管理も含む
    @Published var isRecording = false
    @Published var permissionGranted = false
}
```

**パターン2: Business Service (KeychainService, MediaService)**
```swift
class KeychainService {
    static let shared = KeychainService()
    private init() {} // Singleton pattern
    
    // ビジネスルールに特化した機能
    var isProVersion: Bool { get set }
}
```

**教訓:**
- UI状態を管理するサービスは`@MainActor`で統一
- ビジネスルールサービスはSingleton or Dependency Injection
- プラットフォーム依存とビジネスロジックの分離

---

## 🔒 Security Implementation Patterns

### プライバシー権限管理の標準化

**Before (脆弱性あり):**
```swift
// UserDefaultsは改ざん可能
let isPro = UserDefaults.standard.bool(forKey: "isProVersion")
```

**After (セキュア):**
```swift
// Keychain使用で改ざん防止
let isPro = KeychainService.shared.isProVersion
```

**学んだベストプラクティス:**
1. **段階的セキュリティ**: 機密度に応じた保存方法の選択
   - 一般設定: UserDefaults
   - 機密情報: Keychain
   - 超機密: Server-side validation

2. **透明性の確保**: プライバシー権限の明確な説明
```swift
INFOPLIST_KEY_NSCameraUsageDescription = "具体的な利用目的と保存場所を明記";
```

3. **Migration Strategy**: 既存データの安全な移行
```swift
func migrateFromUserDefaults() {
    if let oldValue = UserDefaults.standard.object(forKey: oldKey) {
        // Keychainに移行
        // UserDefaultsから削除
    }
}
```

### API互換性対応パターン

**iOS Version Compatibility Pattern:**
```swift
private func checkPermissionsAsync() async {
    if #available(iOS 17.0, *) {
        // 新しいAPI
        switch AVAudioApplication.shared.recordPermission {
        case .granted: // ...
        }
    } else {
        // レガシーAPI
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: // ...
        }
    }
}
```

**教訓:**
- 新しいiOS版本でのAPI変更を定期的にチェック
- `@available`属性による条件分岐の活用
- レガシーサポートの維持期間を明確化

---

## 🧵 Concurrency and Memory Management

### MainActor Patterns

**UI更新の確実性:**
```swift
@MainActor
class RecordingViewModel: ObservableObject {
    func handleRecordingCompleted(url: URL) {
        // 既にMainActor上で実行される
        showSuccessMessage = true
        recordingCompleted = true
    }
}
```

**非同期処理との組み合わせ:**
```swift
Task {
    await someBackgroundWork()
    
    await MainActor.run {
        // UI更新
        self.isLoading = false
    }
}
```

### Memory Management Patterns

**Timer Management:**
```swift
class AudioRecorderService {
    private var recordingTimer: Timer?
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil // 重要: nilを設定
    }
    
    deinit {
        stopRecordingTimer() // 確実なクリーンアップ
    }
}
```

**Combine Publisher Management:**
```swift
class RecordingViewModel {
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        cancellables.removeAll() // メモリリーク防止
    }
}
```

**教訓:**
- リソースの取得と解放を対で実装
- deinitでの確実なクリーンアップ
- weak selfの活用で循環参照を防止

---

## 🎯 Error Handling Strategies

### 構造化エラーハンドリング

**Service Level Errors:**
```swift
enum CameraError: LocalizedError {
    case permissionDenied
    case sessionConfigurationFailed
    case recordingFailed(String)
    
    var errorDescription: String? {
        // ユーザーフレンドリーなメッセージ
    }
}
```

**ViewModel Error Propagation:**
```swift
@MainActor
class RecordingViewModel: ObservableObject {
    @Published var errorMessage: String?
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        // ログ記録
        print("RecordingError: \(error)")
    }
}
```

### Validation and Defensive Programming

**入力検証の徹底:**
```swift
func startRecording() async -> Bool {
    guard !isRecording else { return false }
    guard permissionGranted else { return false }
    guard let url = generateValidURL() else { return false }
    
    // 実際の処理
}
```

**エラー回復の実装:**
```swift
do {
    try await recordingOperation()
} catch RecordingError.storageFulll {
    // 自動的にクリーンアップを試行
    try await cleanupOldFiles()
    try await recordingOperation() // リトライ
} catch {
    // エラーをユーザーに報告
    handleError(error)
}
```

---

## 🚀 Performance Optimization Patterns

### Resource Management

**効率的なサムネイル生成:**
```swift
private func generateVideoThumbnail(for url: URL) async -> URL? {
    // バックグラウンドキューでの処理
    let asset = AVAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    
    // メモリ効率的な画像処理
    guard let cgImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: nil) else {
        return nil
    }
    // ...
}
```

**ストレージ制限の動的管理:**
```swift
func isStorageLimitReached() -> Bool {
    let isProVersion = KeychainService.shared.isProVersion
    
    if isProVersion {
        return false // 有料版は無制限
    }
    
    let currentUsage = getTotalStorageUsed()
    let limit = Constants.Storage.freeVersionStorageLimit()
    
    return currentUsage >= limit
}
```

### Network and I/O Optimization

**非同期I/O処理:**
```swift
func saveToDocuments(data: Data, fileName: String) async throws -> URL {
    let documentsURL = Constants.Storage.documentsDirectory
    let fileURL = documentsURL.appendingPathComponent(fileName)
    
    // バックグラウンドでのファイル書き込み
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .background).async {
            do {
                try data.write(to: fileURL)
                continuation.resume(returning: fileURL)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

---

## 📱 SwiftUI Integration Best Practices

### EnvironmentObject vs ObservableObject

**適切な使い分け:**
```swift
// App全体で共有: EnvironmentObject
@main
struct MINEApp: App {
    @StateObject private var diContainer = DIContainer()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(diContainer)
        }
    }
}

// 特定のView階層: ObservableObject
struct RecordingView: View {
    @StateObject private var viewModel: RecordingViewModel
    
    init(recordType: RecordType) {
        _viewModel = StateObject(wrappedValue: RecordingViewModel(recordType: recordType))
    }
}
```

### State Management Patterns

**複雑な状態管理:**
```swift
@MainActor
class RecordingViewModel: ObservableObject {
    // UI状態
    @Published var isRecording = false
    @Published var showSuccessMessage = false
    
    // エラー状態
    @Published var errorMessage: String?
    
    // 計算プロパティで複雑なロジックを隠蔽
    var formattedRecordingTime: String {
        switch recordType {
        case .video:
            return formatVideoTime(recordingTime)
        case .audio:
            return formatAudioTime(recordingTime)
        }
    }
}
```

---

## 🔄 Development Workflow Optimizations

### Build Configuration Management

**Info.plist管理の標準化:**
- `GENERATE_INFOPLIST_FILE = YES`を使用
- プライバシー権限は`INFOPLIST_KEY_*`形式でproject.pbxprojに記載
- 手動Info.plistファイルとの競合を避ける

**Clean Build Strategy:**
```bash
# 重要な変更後は必ずクリーンビルド
rm -rf ~/Library/Developer/Xcode/DerivedData/MINE-*
xcodebuild clean -scheme MINE
xcodebuild build -scheme MINE
```

### Version Control Best Practices

**コミット戦略:**
1. **Atomic Commits**: 1つの機能/修正につき1つのコミット
2. **Conventional Commits**: feat:, fix:, refactor: などのプレフィックス使用
3. **詳細な説明**: 何を変更したかではなく、なぜ変更したかを記述

**ブランチ戦略:**
- `main`: 安定版
- `feature/*`: 新機能開発
- `fix/*`: バグ修正
- `refactor/*`: リファクタリング

---

## 🧪 Testing Strategies

### Unit Testing Patterns

**Service Layer Testing:**
```swift
class KeychainServiceTests: XCTestCase {
    func testProVersionSetting() {
        let service = KeychainService.shared
        
        service.isProVersion = true
        XCTAssertTrue(service.isProVersion)
        
        service.isProVersion = false
        XCTAssertFalse(service.isProVersion)
    }
}
```

**ViewModel Testing:**
```swift
class RecordingViewModelTests: XCTestCase {
    func testRecordingStateManagement() async {
        let viewModel = RecordingViewModel(...)
        
        XCTAssertFalse(viewModel.isRecording)
        
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)
    }
}
```

### Integration Testing

**E2E Recording Flow:**
1. 権限許可の確認
2. 録画開始・停止の動作
3. ファイル保存の確認
4. UI状態の更新確認

---

## 📊 Performance Monitoring

### Key Performance Indicators

**メモリ使用量:**
- 録画中のピークメモリ使用量 < 100MB
- アイドル時のメモリ使用量 < 50MB

**応答性:**
- UI操作の応答時間 < 100ms
- 録画開始時間 < 500ms

**ストレージ効率:**
- サムネイル生成時間 < 1秒
- ファイル圧縮率 > 70%

### Monitoring Tools

**デバッグ用ログ:**
```swift
private func logPerformance<T>(operation: String, execute: () throws -> T) rethrows -> T {
    let startTime = Date()
    let result = try execute()
    let duration = Date().timeIntervalSince(startTime)
    print("[\(operation)] 実行時間: \(duration)秒")
    return result
}
```

---

## 🎓 Key Takeaways

### 技術的教訓

1. **セキュリティファースト**: 最初からセキュリティを考慮した設計
2. **段階的な実装**: 小さな機能から始めて段階的に複雑化
3. **エラーハンドリング重視**: エラーは機能の一部として設計
4. **テスタビリティ**: 依存関係注入とprotocolベース設計
5. **ドキュメント化**: 学習内容の継続的な記録

### プロセス改善

1. **定期的なコードレビュー**: セキュリティとパフォーマンスの観点
2. **継続的なリファクタリング**: 技術的負債の蓄積防止
3. **自動化の活用**: ビルド・テスト・デプロイメントプロセス
4. **知見共有**: 学習内容のチーム全体での共有

### 次のステップ

1. **Repository層の完成**: データアクセス層の統一
2. **パフォーマンス最適化**: メモリとCPU使用量の改善
3. **テストカバレッジ向上**: 80%以上の達成
4. **CI/CD構築**: 自動化されたビルドとテストパイプライン

---

## 更新履歴

- **2025-09-03**: 初版作成 - アーキテクチャパターン、セキュリティ実装、エラーハンドリング
- **次回更新予定**: Repository実装パターン、パフォーマンス最適化手法

---

**Note**: このドキュメントは開発チームの知識ベースとして継続的に更新してください。新しい技術パターンや解決策を発見した際は、必ず記録を追加してください。