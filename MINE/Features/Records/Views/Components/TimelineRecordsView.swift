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
        VStack(spacing: 0) {
            // タイムスケールコントロール
            timeScaleControl
            
            // タイムラインコンテンツ
            timelineContent
        }
        .background(Theme.background)
    }
    
    // MARK: - Time Scale Control
    private var timeScaleControl: some View {
        VStack(spacing: 8) {
            // タイムスケール選択
            Picker("時間軸", selection: $selectedTimeScale) {
                Text("日").tag(TimeScale.day)
                Text("週").tag(TimeScale.week)
                Text("月").tag(TimeScale.month)
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
                ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { period in
                    TimelinePeriodSection(
                        period: period,
                        records: groupedRecords[period] ?? [],
                        timeScale: selectedTimeScale,
                        comparisonMode: comparisonMode,
                        onRecordTap: onRecordTap
                    )
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadDataAsync()
        }
    }
    
    // MARK: - Computed Properties
    private var groupedRecords: [Date: [Record]] {
        let calendar = Calendar.current
        return Dictionary(grouping: viewModel.filteredRecords) { record in
            switch selectedTimeScale {
            case .day:
                return calendar.startOfDay(for: record.createdAt)
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: record.createdAt)?.start ?? record.createdAt
            case .month:
                return calendar.dateInterval(of: .month, for: record.createdAt)?.start ?? record.createdAt
            }
        }
    }
    
    private var currentPeriodText: String {
        let formatter = DateFormatter()
        switch selectedTimeScale {
        case .day:
            formatter.dateStyle = .medium
            return "最近30日"
        case .week:
            return "最近12週"
        case .month:
            formatter.dateFormat = "yyyy年M月"
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
        case .day:
            formatter.dateStyle = .medium
            return formatter.string(from: period)
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
    case day = "day"
    case week = "week"
    case month = "month"
    
    var displayName: String {
        switch self {
        case .day: return "日"
        case .week: return "週"
        case .month: return "月"
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