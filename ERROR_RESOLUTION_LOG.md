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

---

## 2025年9月5日 - 高度なクロッピング機能開発セッション

### 開発概要
iPhone純正カメラアプリレベルの高品質クロッピング機能を実装。ユーザーフィードバックに基づいて動画表示領域ベースのクロッピングシステムを構築。

### 解決したエラーと学習内容

#### 1. 文字列フォーマットエラー (Swift構文エラー)

**エラー内容**:
```
error: consecutive statements on a line must be separated by ';'
```

**根本原因**: 複数行文字列で `\n` エスケープシーケンスを使用し、Swiftの文字列リテラルとして不正な形式

**解決方法**:
```swift
// ❌ 間違った書き方
"])\n        \n        // ScrollView設定\n"

// ✅ 正しい書き方  
])
        
        // ScrollView設定
```

**学習ポイント**: SwiftのMultiline String Literalは実際の改行を使用する

#### 2. CGSize プロパティアクセスエラー

**エラー内容**:
```
error: Value of type 'CGSize' has no member 'x'
```

**根本原因**: `CGSize` に `.x` と `.y` プロパティでアクセスしようとした

**解決方法**:
```swift
// ❌ 間違った書き方
let x = videoSize.x
let y = videoSize.y

// ✅ 正しい書き方
let width = videoSize.width  
let height = videoSize.height
```

**学習ポイント**: CGSize: width,height / CGPoint: x,y / CGRect: origin,size

#### 3. AVLayerVideoGravity 定数エラー

**エラー内容**:
```
error: type 'AVLayerVideoGravity' has no member 'resizeAspectFit'
```

**解決方法**:
```swift
// ❌ 間違った書き方
playerLayer.videoGravity = .resizeAspectFit

// ✅ 正しい書き方
playerLayer.videoGravity = .resizeAspect
```

#### 4. Extension重複宣言エラー

**エラー内容**:
```
error: invalid redeclaration of 'ratio'
```

**根本原因**: 複数ファイルで同じ extension を宣言
**解決方法**: ProfessionalCropView.swiftから重複extensionを削除

#### 5. アスペクト比テンプレートでのクラッシュ

**根本原因**: 
- UI更新が背景スレッドで実行
- 無効なパラメータでの座標計算
- SmartCropOverlayViewの初期化タイミング問題

**解決方法**:
```swift
func applyCropAspectRatio(_ ratio: CropAspectRatio) {
    // メインスレッドで安全に実行
    DispatchQueue.main.async { [weak self] in
        guard let self = self,
              let videoSize = self.editorService?.videoSize,
              videoSize.width > 0 && videoSize.height > 0 else { 
            return 
        }
        // 安全な処理
    }
}
```

#### 6. 重複UIコンポーネント問題

**問題**: 画面外に謎のクロップ枠が表示
**根本原因**: VideoEditorViewの古い `cropOverlay` と VideoPlayerCropViewの新しい `SmartCropOverlayView` の二重描画
**解決方法**: 古いcropOverlayを完全削除し、単一のSmartCropOverlayViewに統一

### 開発で実装した高度な技術

#### 1. 動画表示領域ベースクロッピングシステム
```swift
/// 動画の実際の表示領域を計算（アスペクトフィット）
private func updateVideoDisplayRect() {
    // 動画アスペクト比 vs ビューアスペクト比で完璧な表示領域計算
}
```

#### 2. インテリジェント座標変換エンジン
```swift
/// ビュー座標から動画座標への変換
private func convertViewToVideoCoordinates(_ viewRect: CGRect) -> CGRect {
    // 相対座標計算 → 動画座標変換 → 境界制限の3段階処理
}
```

#### 3. 同時ジェスチャー認識システム
```swift
// UIGestureRecognizerDelegateでピンチ・パン同時操作を実現
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
}
```

### 開発ベストプラクティス

#### 1. エラー対応の基本原則
1. **段階的修正**: 1つのエラーを修正したら即座にビルド確認
2. **根本原因の特定**: 表面的な修正ではなく本質的な問題を理解
3. **学習の記録**: 同じエラーを繰り返さないためのドキュメント化

#### 2. Swift/iOS開発での注意点
- **構造体プロパティの正確な把握**（CGSize, CGPoint, CGRect）
- **スレッド安全性の確保**（UI更新はメインスレッド）
- **Extension の重複回避**
- **AVFoundation定数の正確性**

#### 3. アーキテクチャ設計原則
- **単一責任原則の遵守**
- **UIコンポーネントの明確な分離**
- **古いコードの適切な除去**
- **座標系変換の精密な実装**

### 今後の予防策
1. **コード書く前の設計確認**
2. **既存コンポーネントとの重複チェック**  
3. **パラメータ有効性の事前検証**
4. **スレッド安全性の常時考慮**
5. **構造体プロパティの正確な把握**

### 関連ファイル
- `MINE/Features/VideoEditor/Views/Components/VideoPlayerCropView.swift`
- `MINE/Features/VideoEditor/Views/Components/ProfessionalCropView.swift`
- `MINE/Features/VideoEditor/Views/VideoEditorView.swift`
- `MINE/Features/VideoEditor/ViewModels/VideoEditorViewModel.swift`
- `MINE/Features/VideoEditor/Views/Components/VideoTimelineView.swift`

---

## 2025年9月5日 - VideoPlayerCropView.swiftビルドエラー修正

### 問題概要
VideoPlayerCropView.swiftで複数のビルドエラーが発生し、コンパイルが通らない状態。

### エラー詳細
1. **CropOverlayViewの重複宣言エラー**
   ```
   /Users/sora1/CODE/MINE/MINE/Features/VideoEditor/Views/Components/VideoPlayerCropView.swift:493:8: 
   error: invalid redeclaration of 'CropOverlayView'
   ```

2. **引数なしメソッドへの引数渡しエラー**
   ```
   /Users/sora1/CODE/MINE/MINE/Features/VideoEditor/Views/Components/VideoPlayerCropView.swift:63:49: 
   error: argument passed to call that takes no arguments
   ```

3. **onReceiveメンバーなしエラー**
   ```
   /Users/sora1/CODE/MINE/MINE/Features/VideoEditor/Views/Components/VideoPlayerCropView.swift:64:26: 
   error: value of type 'CropOverlayView' has no member 'onReceive'
   ```

4. **CGSize.isEmptyプロパティなしエラー**
   ```
   /Users/sora1/CODE/MINE/MINE/Features/VideoEditor/Views/Components/VideoPlayerCropView.swift:145:30: 
   error: value of type 'CGSize' has no member 'isEmpty'
   ```

### 根本原因分析

#### 1. ファイル構造の混乱
- `HybridCropSystem.swift`と`VideoPlayerCropView.swift`の両方に`CropOverlayView`が定義されていた
- 複数のProCropSystemファイルにも類似の構造体が存在し、名前衝突が発生

#### 2. 依存関係の不整合
- `onReceive`メソッドを使用するため`Combine`フレームワークのインポートが必要
- SwiftUIのViewModifierの適用順序に問題

#### 3. プラットフォームAPI互換性
- `CGSize.isEmpty`はiOS 16.0以降のAPI
- 後方互換性のためには`.zero`比較を使用する必要

### 解決手順

#### Step 1: 重複ファイル整理
```bash
# 不要な重複ファイルを削除
rm /Users/sora1/CODE/MINE/HybridCropSystem.swift
```

#### Step 2: Combineフレームワーク追加
```swift
// VideoPlayerCropView.swiftに追加
import Combine
```

#### Step 3: 名前衝突回避
```swift
// CropOverlayView → HybridCropOverlayViewに変更
struct HybridCropOverlayView: View {
    @ObservedObject var controller: CropController
    // ...
}
```

#### Step 4: CGSize.isEmpty対応
```swift
// iOS 16.0未満対応の修正
guard containerSize != .zero && videoSize.width > 0 && videoSize.height > 0 else {
    // ...
}
```

#### Step 5: onChange警告修正
```swift
// iOS 17対応のonChange構文
.onChange(of: geometry.size) { _, newSize in
    cropController.updateContainerSize(newSize)
}
.onChange(of: aspectRatio) { _, newRatio in
    cropController.updateAspectRatio(newRatio)
}
```

### 修正結果
- **ビルドステータス**: ✅ BUILD SUCCEEDED
- **エラー件数**: 4件 → 0件
- **警告件数**: 2件 → 0件

### 技術的改善点

#### 1. アーキテクチャの整理
- 重複するコンポーネントを統合し、単一責任原則を維持
- ファイル間の依存関係を明確化

#### 2. 後方互換性の確保
- iOS 16.0以降のAPIに依存しない実装に変更
- プラットフォーム固有の機能は適切にチェック

#### 3. SwiftUI最新構文対応
- 非推奨のonChange構文を最新版に更新
- コンパイラ警告の完全解決

### 予防策

#### 1. ファイル管理
- 同一機能の構造体は単一ファイルに集約
- 名前空間を適切に管理し、衝突を回避

#### 2. 依存関係管理
- 使用するFrameworkは明示的にインポート
- プラットフォーム互換性を常に考慮

#### 3. 継続的品質管理
- 定期的なビルドチェックの実施
- 警告レベルでの修正対応

### 関連ファイル
- `MINE/Features/VideoEditor/Views/Components/VideoPlayerCropView.swift` (修正)
- `HybridCropSystem.swift` (削除)

### 学習ポイント
- **SwiftUIの名前空間管理**: 同名構造体の衝突回避方法
- **後方互換性設計**: プラットフォームAPIの適切な使用
- **エラー解析手法**: ビルドエラーの体系的な解決アプローチ
- **依存関係理解**: フレームワーク間の相互作用