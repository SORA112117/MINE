# UltraCropSystem - 新クロッピングアルゴリズム設計

## 🔍 参考HTMLアルゴリズム分析結果

### 成功要因
1. **明確な状態分離**: `isDragging`, `isResizing`, `isDraggingCrop`の3状態で完全制御
2. **厳格なタッチ判定**: ハンドル範囲の正確な計算とフォールバック処理
3. **予測可能な境界制限**: キャンバス境界内での確実な制約処理
4. **直接的な座標操作**: 複雑な変換を避けた直接座標管理

### 問題となっていた現行システム
- 4コンポーネント分離による複雑性
- 座標変換の多段階処理
- フレームサイズの予期しないリセット
- タッチ判定の競合問題

## 🚀 UltraCropSystem設計方針

### Core Philosophy
**Single Source of Truth**: 単一ビューですべての状態と操作を管理

### アーキテクチャ
```swift
UltraCropView: UIView {
    // 状態管理
    enum CropState {
        case idle           // 待機状態
        case dragging       // 新規領域作成
        case resizing       // ハンドルリサイズ
        case moving         // 領域移動
    }
    
    // 座標系
    private var videoDisplayRect: CGRect    // 動画表示領域
    private var cropRect: CGRect           // クロップ領域
    
    // 状態フラグ
    private var currentState: CropState = .idle
    private var activeHandle: HandleType?
    private var hasValidCropArea: Bool = false
}
```

## 🔧 核心アルゴリズム

### 1. タッチ判定システム
```swift
func determineTouchAction(at point: CGPoint) -> CropState {
    // Step 1: ハンドル範囲チェック (厳格)
    if let handle = detectHandleAt(point) {
        activeHandle = handle
        return .resizing
    }
    
    // Step 2: クロップ領域内チェック
    if hasValidCropArea && cropRect.contains(point) {
        // Step 2.1: ハンドル周辺除外チェック
        if !isNearAnyHandle(point) {
            return .moving
        }
    }
    
    // Step 3: 新規作成
    return .dragging
}

func detectHandleAt(_ point: CGPoint) -> HandleType? {
    let handleSize: CGFloat = 44 // 十分なタッチ領域
    let handles = calculateHandlePositions()
    
    for (type, position) in handles {
        let handleRect = CGRect(
            x: position.x - handleSize/2,
            y: position.y - handleSize/2,
            width: handleSize,
            height: handleSize
        )
        if handleRect.contains(point) {
            return type
        }
    }
    return nil
}
```

### 2. 状態固定システム
```swift
func preserveCropSize() {
    // ユーザーが調整したサイズを保持
    if hasValidCropArea {
        savedCropSize = cropRect.size
    }
}

func applyCropAspectRatio(_ ratio: CropAspectRatio) {
    guard hasValidCropArea else {
        // 初回設定時のみデフォルトサイズ適用
        createDefaultCropRect(for: ratio)
        return
    }
    
    // 既存のクロップサイズを維持しつつアスペクト比のみ調整
    let currentCenter = CGPoint(x: cropRect.midX, y: cropRect.midY)
    let newSize = calculateConstrainedSize(
        currentSize: cropRect.size,
        aspectRatio: ratio,
        within: videoDisplayRect
    )
    
    cropRect = CGRect(
        x: currentCenter.x - newSize.width/2,
        y: currentCenter.y - newSize.height/2,
        width: newSize.width,
        height: newSize.height
    )
}
```

### 3. 厳格境界システム
```swift
func constrainCropRect(_ rect: CGRect, to bounds: CGRect) -> CGRect {
    var constrained = rect
    
    // サイズ制限
    constrained.size.width = min(constrained.size.width, bounds.width)
    constrained.size.height = min(constrained.size.height, bounds.height)
    
    // 位置制限
    if constrained.origin.x < bounds.minX {
        constrained.origin.x = bounds.minX
    }
    if constrained.origin.y < bounds.minY {
        constrained.origin.y = bounds.minY
    }
    if constrained.maxX > bounds.maxX {
        constrained.origin.x = bounds.maxX - constrained.width
    }
    if constrained.maxY > bounds.maxY {
        constrained.origin.y = bounds.maxY - constrained.height
    }
    
    return constrained
}
```

### 4. ジェスチャー統合システム
```swift
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let point = touch.location(in: self)
    
    currentState = determineTouchAction(at: point)
    touchStartPoint = point
    
    switch currentState {
    case .resizing:
        startFrame = cropRect
    case .moving:
        moveStartPoint = point
        moveOffset = CGPoint(
            x: point.x - cropRect.midX,
            y: point.y - cropRect.midY
        )
    case .dragging:
        cropRect = CGRect(origin: point, size: .zero)
        hasValidCropArea = false
    case .idle:
        break
    }
}
```

## 📊 期待される改善効果

### 解決される問題
1. ✅ **フレームサイズリセット問題**: 状態固定システムで解決
2. ✅ **タッチ判定競合**: 単一ビューでの統合制御で解決
3. ✅ **座標変換複雑性**: 直接座標操作で解決
4. ✅ **予期しない動作**: 明確な状態管理で解決

### パフォーマンス向上
- 4コンポーネント → 1コンポーネント (75% 削減)
- 複雑な座標変換 → 直接操作 (処理速度向上)
- UIKit純正手法 → 最高レスポンス

### 保守性向上
- 単一ファイルでの完全制御
- HTMLアルゴリズムから実証済みのロジック移植
- 明確な状態遷移

## 🎯 実装戦略

### Phase 1: UltraCropView基盤作成
- 単一ビュー設計
- 基本状態管理システム

### Phase 2: タッチ判定システム実装
- 厳格なハンドル検出
- 状態遷移制御

### Phase 3: 境界制限とアスペクト比システム
- HTMLアルゴリズムベースの制約システム
- サイズ保持システム

### Phase 4: 視覚的要素とアニメーション
- iPhone純正風UI
- スムーズなフィードバック