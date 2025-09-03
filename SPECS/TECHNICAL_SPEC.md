# MINE - 技術仕様書

## 1. 技術スタック

### 1.1 プラットフォーム
- iOS 16.0以上
- iPadOS 16.0以上
- Swift 5.9
- SwiftUI + UIKit（カメラ/メディア処理）

### 1.2 フレームワーク
#### Core
- SwiftUI: メインUI
- Combine: リアクティブプログラミング
- Core Data: ローカルデータ永続化

#### メディア処理
- AVFoundation: カメラ/録音
- Photos: フォトライブラリアクセス
- Vision: 画像分析（将来のAI機能用）
- CoreImage: 画像編集

#### その他
- CloudKit: クラウド同期（有料版）
- StoreKit 2: アプリ内課金
- UserNotifications: リマインダー通知

## 2. アーキテクチャ

### 2.1 設計パターン
- MVVM + Clean Architecture
- Repository Pattern（データ層）
- Coordinator Pattern（画面遷移）

### 2.2 ディレクトリ構造
```
MINE/
├── App/
│   ├── MINEApp.swift
│   └── AppCoordinator.swift
├── Core/
│   ├── Models/
│   ├── Database/
│   ├── Network/
│   └── Services/
├── Features/
│   ├── Home/
│   ├── Records/
│   ├── Settings/
│   └── Recording/
├── Shared/
│   ├── UI/
│   ├── Extensions/
│   └── Utilities/
└── Resources/
```

## 3. データモデル

### 3.1 Core Dataエンティティ

#### Record
```swift
- id: UUID
- type: RecordType (video/audio/image)
- createdAt: Date
- updatedAt: Date
- duration: TimeInterval?
- fileURL: URL
- thumbnailURL: URL?
- comment: String?
- tags: Set<Tag>
- folder: Folder?
- templateId: UUID?
```

#### Folder
```swift
- id: UUID
- name: String
- parentFolder: Folder?
- subFolders: Set<Folder>
- records: Set<Record>
- createdAt: Date
- color: String
```

#### Tag
```swift
- id: UUID
- name: String
- color: String
- records: Set<Record>
- usageCount: Int
```

#### RecordTemplate
```swift
- id: UUID
- name: String
- recordType: RecordType
- duration: TimeInterval?
- cropRect: CGRect?
- tags: Set<Tag>
- folder: Folder?
```

### 3.2 ストレージ設計
#### ローカルストレージ
- Documents/Records/: メディアファイル
- Documents/Thumbnails/: サムネイル
- Documents/Templates/: テンプレート設定
- Core Data: メタデータ

#### クラウドストレージ（有料版）
- CloudKit Private Database
- 自動同期（WiFi時）
- オンデマンドダウンロード

## 4. UI/UX設計

### 4.1 画面構成
```
TabView
├── HomeTab
│   ├── DashboardView
│   ├── QuickRecordButton
│   └── RecentRecordsView
├── RecordsTab
│   ├── RecordGridView
│   ├── TimelineView
│   └── HeatmapView
└── SettingsTab
    ├── GeneralSettings
    ├── SubscriptionSettings
    └── AboutView
```

### 4.2 テーマカラー
```swift
enum Theme {
    static let primary = Color(hex: "4A90A4")     // 青緑
    static let secondary = Color(hex: "67B3A3")   // ミント
    static let accent = Color(hex: "F4A261")      // オレンジ
    static let background = Color(hex: "FAF9F7")  // オフホワイト
    static let text = Color(hex: "2C3E50")        // ダークグレー
}
```

## 5. パフォーマンス要件

### 5.1 アプリサイズ
- 初期インストール: < 50MB
- 無料版最大使用: デバイス容量の10%まで

### 5.2 レスポンス
- アプリ起動: < 2秒
- 画面遷移: < 0.3秒
- 記録開始: < 1秒
- サムネイル生成: < 0.5秒

### 5.3 バッテリー
- バックグラウンド処理最小化
- 動画処理時の最適化

## 6. セキュリティ

### 6.1 データ保護
- FileProtectionComplete
- Keychain: 認証トークン
- CloudKit: エンドツーエンド暗号化

### 6.2 プライバシー
- カメラ/マイク権限
- フォトライブラリ権限
- 通知権限（オプション）

## 7. 開発フェーズ

### Phase 1 (MVP) - 6週間
- 基本記録機能
- ローカルストレージ
- 基本UI（タブ構造）
- フォルダ/タグ管理

### Phase 2 - 4週間
- フリーミアム実装
- CloudKit統合
- 高度な編集機能
- 共有機能

### Phase 3 - 4週間
- AI分析機能
- パフォーマンス最適化
- UI/UX改善