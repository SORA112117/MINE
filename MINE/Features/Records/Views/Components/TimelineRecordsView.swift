import SwiftUI

// MARK: - Timeline Records View
struct TimelineRecordsView: View {
    @ObservedObject var viewModel: RecordsViewModel
    let onRecordTap: (Record) -> Void
    
    @State private var selectedTimeScale: TimeScale = .week
    @State private var scrollOffset: CGFloat = 0
    @State private var showingComparisonPicker = false
    @State private var comparisonMode: ComparisonMode = .sideBySide
    
    var body: some View {
        timelineContent
            .background(Theme.background)
    }
    
    // MARK: - Time Scale Control
    private var timeScaleControl: some View {
        VStack(spacing: 8) {
            // タイムスケール選択
            Picker("時間軸", selection: $selectedTimeScale) {
                Text("週").tag(TimeScale.week)
                Text("月").tag(TimeScale.month)
                Text("全期間").tag(TimeScale.all)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedTimeScale) { oldValue, newValue in
                // インタラクティブフィードバック
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                viewModel.changeTimeScale(to: newValue)
            }
            
            // 比較モード切り替え
            HStack {
                Text("表示モード:")
                    .font(.caption)
                    .foregroundColor(Theme.gray5)
                
                Button(action: toggleComparisonMode) {
                    HStack(spacing: 4) {
                        Image(systemName: comparisonMode.icon)
                            .font(.caption)
                        Text(comparisonMode.displayName)
                            .font(.caption)
                    }
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Theme.primary.opacity(0.1))
                    )
                }
                
                Spacer()
                
                // 表示期間情報
                Text(currentPeriodText)
                    .font(.caption)
                    .foregroundColor(Theme.gray4)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(color: Theme.shadowColor, radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Timeline Content
    private var timelineContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 現在の日付・期間表示
                currentPeriodHeader
                
                // タグ別横並び表示
                tagBasedRecordsView
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDataAsync()
        }
    }
    
    // MARK: - Current Period Header
    private var currentPeriodHeader: some View {
        VStack(spacing: 12) {
            // 時間軸選択
            Picker("時間軸", selection: $selectedTimeScale) {
                Text("週").tag(TimeScale.week)
                Text("月").tag(TimeScale.month)
                Text("全期間").tag(TimeScale.all)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedTimeScale) { oldValue, newValue in
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                viewModel.changeTimeScale(to: newValue)
            }
            
            // 現在の期間表示
            VStack(spacing: 8) {
                Text(currentPeriodText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                if !viewModel.filteredRecords.isEmpty {
                    Text("\(viewModel.filteredRecords.count) 件の記録")
                        .font(.caption)
                        .foregroundColor(Theme.gray5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(Theme.gray1.opacity(0.3))
        .cornerRadius(12)
    }
    
    // MARK: - Tag Based Records View
    private var tagBasedRecordsView: some View {
        LazyVStack(spacing: 20) {
            ForEach(groupedRecordsByTag.keys.sorted(), id: \.self) { tagName in
                TagRowSection(
                    tagName: tagName,
                    records: groupedRecordsByTag[tagName] ?? [],
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedRecords: viewModel.selectedRecords,
                    onRecordTap: onRecordTap
                )
            }
        }
    }
    
    // タグ別グループ化
    private var groupedRecordsByTag: [String: [Record]] {
        let filtered = viewModel.filteredRecords
        var grouped: [String: [Record]] = [:]
        
        // タグなしの記録
        var untaggedRecords: [Record] = []
        
        for record in filtered {
            if record.tags.isEmpty {
                untaggedRecords.append(record)
            } else {
                // 各タグごとに記録を分類
                for tag in record.tags {
                    if grouped[tag.name] == nil {
                        grouped[tag.name] = []
                    }
                    grouped[tag.name]?.append(record)
                }
            }
        }
        
        // タグなしの記録があれば追加
        if !untaggedRecords.isEmpty {
            grouped["タグなし"] = untaggedRecords
        }
        
        return grouped
    }
    
    // フォルダ別セクション表示
    private var folderSections: some View {
        VStack(spacing: 16) {
            // セクションタイトル
            HStack {
                Text("フォルダ別表示")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // フォルダごとのセクション
            ForEach(groupedRecordsByFolder.keys.sorted(), id: \.self) { folderName in
                FolderSection(
                    folderName: folderName,
                    records: groupedRecordsByFolder[folderName] ?? [],
                    onRecordTap: onRecordTap
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    private var groupedRecords: [Date: [Record]] {
        let calendar = Calendar.current
        return Dictionary(grouping: viewModel.filteredRecords) { record in
            switch selectedTimeScale {
            case .all:
                // 全期間の場合は年単位でグループ化
                return calendar.dateInterval(of: .year, for: record.createdAt)?.start ?? record.createdAt
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: record.createdAt)?.start ?? record.createdAt
            case .month:
                return calendar.dateInterval(of: .month, for: record.createdAt)?.start ?? record.createdAt
            }
        }
    }
    
    // タグごとのグループ化（フォルダ機能は削除）
    private var groupedRecordsByFolder: [String: [Record]] {
        return Dictionary(grouping: viewModel.filteredRecords) { record in
            // フォルダ機能は削除、タグベース分類に移行
            return "全ての記録"
        }
    }
    
    private var currentPeriodText: String {
        switch selectedTimeScale {
        case .all:
            return "全期間の記録"
        case .week:
            return "最近12週"
        case .month:
            return "最近12ヶ月"
        }
    }
    
    // MARK: - Actions
    private func toggleComparisonMode() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        switch comparisonMode {
        case .sideBySide:
            comparisonMode = .overlay
        case .overlay:
            comparisonMode = .carousel
        case .carousel:
            comparisonMode = .sideBySide
        }
    }
}

// MARK: - Timeline Period Section
struct TimelinePeriodSection: View {
    let period: Date
    let records: [Record]
    let timeScale: TimeScale
    let comparisonMode: ComparisonMode
    let onRecordTap: (Record) -> Void
    
    @State private var selectedRecordIndex = 0
    @State private var showingAllRecords = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダー
            sectionHeader
            
            // レコード表示エリア
            recordsDisplayArea
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(Constants.UI.cornerRadius)
        .shadow(color: Theme.shadowColor, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Section Header
    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedPeriod)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Text("\(records.count)件の記録")
                    .font(.caption)
                    .foregroundColor(Theme.gray5)
            }
            
            Spacer()
            
            // 全件表示ボタン
            if records.count > 2 {
                Button(action: { showingAllRecords.toggle() }) {
                    Text(showingAllRecords ? "折りたたむ" : "全て表示")
                        .font(.caption)
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Records Display Area
    private var recordsDisplayArea: some View {
        Group {
            switch comparisonMode {
            case .sideBySide:
                sideBySideView
            case .overlay:
                overlayView
            case .carousel:
                carouselView
            }
        }
    }
    
    // MARK: - Side by Side View
    private var sideBySideView: some View {
        let displayRecords = showingAllRecords ? records : Array(records.prefix(2))
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(displayRecords, id: \.id) { record in
                    TimelineRecordCard(
                        record: record,
                        comparisonMode: comparisonMode,
                        onTap: { onRecordTap(record) }
                    )
                    .frame(width: 280)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Overlay View
    private var overlayView: some View {
        ZStack {
            // 背景記録（比較対象）
            if records.count >= 2 {
                TimelineRecordCard(
                    record: records[1],
                    comparisonMode: comparisonMode,
                    isBackground: true,
                    onTap: { onRecordTap(records[1]) }
                )
                .opacity(0.6)
            }
            
            // フォアグラウンド記録（最新）
            if !records.isEmpty {
                TimelineRecordCard(
                    record: records[0],
                    comparisonMode: comparisonMode,
                    onTap: { onRecordTap(records[0]) }
                )
            }
            
            // オーバーレイコントロール
            if records.count >= 2 {
                overlayControls
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Carousel View
    private var carouselView: some View {
        VStack(spacing: 8) {
            // メインカード
            if !records.isEmpty {
                TimelineRecordCard(
                    record: records[selectedRecordIndex],
                    comparisonMode: comparisonMode,
                    onTap: { onRecordTap(records[selectedRecordIndex]) }
                )
            }
            
            // カルーセルコントロール
            if records.count > 1 {
                carouselControls
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Overlay Controls
    private var overlayControls: some View {
        VStack {
            Spacer()
            HStack {
                Button("比較表示切替") {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    // オーバーレイの透明度を切り替える処理
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                Spacer()
            }
        }
        .padding()
    }
    
    // MARK: - Carousel Controls
    private var carouselControls: some View {
        HStack {
            // 前へボタン
            Button(action: previousRecord) {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundColor(selectedRecordIndex > 0 ? Theme.primary : Theme.gray3)
            }
            .disabled(selectedRecordIndex <= 0)
            
            // インジケーター
            HStack(spacing: 4) {
                ForEach(0..<records.count, id: \.self) { index in
                    Circle()
                        .fill(index == selectedRecordIndex ? Theme.primary : Theme.gray3)
                        .frame(width: 6, height: 6)
                        .onTapGesture {
                            selectedRecordIndex = index
                        }
                }
            }
            
            // 次へボタン
            Button(action: nextRecord) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(selectedRecordIndex < records.count - 1 ? Theme.primary : Theme.gray3)
            }
            .disabled(selectedRecordIndex >= records.count - 1)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Computed Properties
    private var formattedPeriod: String {
        let formatter = DateFormatter()
        switch timeScale {
        case .all:
            return "全期間"
        case .week:
            let calendar = Calendar.current
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: period) {
                formatter.dateFormat = "M/d"
                let start = formatter.string(from: weekInterval.start)
                let end = formatter.string(from: weekInterval.end)
                return "\(start) - \(end)"
            }
            return formatter.string(from: period)
        case .month:
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: period)
        }
    }
    
    // MARK: - Actions
    private func previousRecord() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if selectedRecordIndex > 0 {
            selectedRecordIndex -= 1
        }
    }
    
    private func nextRecord() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if selectedRecordIndex < records.count - 1 {
            selectedRecordIndex += 1
        }
    }
}

// MARK: - Supporting Enums
enum TimeScale: String, CaseIterable {
    case week = "week"
    case month = "month"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .week: return "週"
        case .month: return "月"
        case .all: return "全期間"
        }
    }
}

enum ComparisonMode: String, CaseIterable {
    case sideBySide = "side-by-side"
    case overlay = "overlay"
    case carousel = "carousel"
    
    var displayName: String {
        switch self {
        case .sideBySide: return "並列"
        case .overlay: return "重ね合わせ"
        case .carousel: return "カルーセル"
        }
    }
    
    var icon: String {
        switch self {
        case .sideBySide: return "rectangle.split.2x1"
        case .overlay: return "square.stack"
        case .carousel: return "arrow.left.arrow.right"
        }
    }
}

// MARK: - Folder Section
struct FolderSection: View {
    let folderName: String
    let records: [Record]
    let onRecordTap: (Record) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // フォルダセクションヘッダー
            HStack {
                Image(systemName: "folder.fill")
                    .font(.title3)
                    .foregroundColor(Theme.primary)
                
                Text(folderName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text("\(records.count)件")
                    .font(.subheadline)
                    .foregroundColor(Theme.gray5)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // レコードリスト
            LazyVStack(spacing: 8) {
                ForEach(records.sorted { $0.createdAt > $1.createdAt }, id: \.id) { record in
                    TimelineRecordCard(
                        record: record,
                        comparisonMode: .sideBySide,
                        onTap: { onRecordTap(record) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color.white)
        .cornerRadius(Constants.UI.cornerRadius)
        .shadow(color: Theme.shadowColor, radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Tag Row Section
struct TagRowSection: View {
    let tagName: String
    let records: [Record]
    let isSelectionMode: Bool
    let selectedRecords: Set<UUID>
    let onRecordTap: (Record) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // タグヘッダー（コンパクト化）
            HStack {
                Text(tagName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text("\(records.count) 件")
                    .font(.caption2)
                    .foregroundColor(Theme.gray5)
            }
            
            // 横スクロール記録リスト（間隔調整）
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(records.sorted { $0.createdAt > $1.createdAt }, id: \.id) { record in
                        CompactRecordCard(
                            record: record,
                            isSelected: selectedRecords.contains(record.id),
                            isSelectionMode: isSelectionMode,
                            onTap: { onRecordTap(record) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Theme.shadowColor, radius: 1, x: 0, y: 1)
    }
}

// MARK: - Compact Record Card
struct CompactRecordCard: View {
    let record: Record
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            if isSelectionMode {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            onTap()
        }) {
            VStack(spacing: 4) {
                // サムネイル/アイコン（小型化）
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.gray1)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: record.type.systemImage)
                                .font(.body)
                                .foregroundColor(Theme.primary)
                        )
                        .overlay(
                            // 選択時のオーバーレイ
                            isSelectionMode && isSelected ?
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Theme.primary.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Theme.primary, lineWidth: 2)
                                )
                            : nil
                        )
                    
                    // 選択インジケーター
                    if isSelectionMode {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Theme.primary : Color.white)
                                        .frame(width: 16, height: 16)
                                    
                                    Circle()
                                        .stroke(isSelected ? Theme.primary : Theme.gray4, lineWidth: 1)
                                        .frame(width: 16, height: 16)
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                }
                                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 0.5)
                            }
                            Spacer()
                        }
                        .frame(width: 60, height: 60)
                        .padding(2)
                    }
                }
                
                // 記録情報（コンパクト化）
                VStack(spacing: 2) {
                    Text(record.title)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    
                    Text(record.createdAt.formatted(.dateTime.month().day()))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.gray4)
                }
            }
            .frame(width: 76)
            .background(
                isSelectionMode && isSelected ?
                Theme.primary.opacity(0.05) :
                Color.clear
            )
            .cornerRadius(8)
            .scaleEffect(isSelectionMode && isSelected ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}