import SwiftUI

// MARK: - Calendar Records View
struct CalendarRecordsView: View {
    @ObservedObject var viewModel: RecordsViewModel
    let onRecordTap: (Record) -> Void
    
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var showingDatePicker = false
    @State private var calendarSize: CalendarSize = .standard
    @State private var selectedRecords: [Record] = []
    
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // カレンダーヘッダー
                calendarHeader
                
                // ヒートマップカレンダー
                heatmapCalendar
                
                // 選択日の詳細
                if !selectedRecords.isEmpty {
                    selectedDateDetailsFullHeight
                } else {
                    emptyStateView
                }
            }
            .background(Theme.background)
        }
        .refreshable {
            await viewModel.loadDataAsync()
        }
        .onAppear {
            updateSelectedRecords()
        }
        .onChange(of: selectedDate) { _, _ in
            updateSelectedRecords()
        }
    }
    
    // MARK: - Calendar Header
    private var calendarHeader: some View {
        VStack(spacing: 8) {
            // 月選択とコントロール
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Theme.primary)
                }
                
                Spacer()
                
                Button(action: { showingDatePicker = true }) {
                    Text(currentMonthText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.text)
                }
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(Theme.primary)
                }
            }
            .padding(.horizontal)
            
            // 統計情報
            monthlyStatsView
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(color: Theme.shadowColor, radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Monthly Stats
    private var monthlyStatsView: some View {
        HStack(spacing: 24) {
            StatItem(
                icon: "calendar",
                title: "記録日数",
                value: "\(activeDaysInMonth)日",
                color: Theme.primary
            )
            
            StatItem(
                icon: "flame.fill",
                title: "連続記録",
                value: "\(currentStreak)日",
                color: Theme.accent
            )
            
            StatItem(
                icon: "chart.bar.fill",
                title: "今月合計",
                value: "\(recordsInCurrentMonth.count)件",
                color: Theme.secondary
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 8) // 下部に余白を追加して重なりを防止
    }
    
    // MARK: - Heatmap Calendar
    private var heatmapCalendar: some View {
        VStack(spacing: 8) {
            // 曜日ヘッダー
            weekdayHeader
            
            // カレンダーグリッド
            calendarGrid
            
            // ヒートマップ凡例
            heatmapLegend
        }
        .padding()
        .background(Color.white)
        .cornerRadius(Constants.UI.cornerRadius)
        .shadow(color: Theme.shadowColor, radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // MARK: - Weekday Header
    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.gray5)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
            ForEach(calendarDays, id: \.self) { date in
                CalendarDayCell(
                    date: date,
                    recordCount: recordsForDate(date).count,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                    maxRecordsInMonth: maxRecordsInMonth,
                    onTap: {
                        selectDate(date)
                    }
                )
            }
        }
    }
    
    // MARK: - Heatmap Legend
    private var heatmapLegend: some View {
        HStack {
            Text("少")
                .font(.caption2)
                .foregroundColor(Theme.gray4)
            
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { intensity in
                    Rectangle()
                        .fill(heatmapColor(for: intensity, maxIntensity: 4))
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)
                }
            }
            
            Text("多")
                .font(.caption2)
                .foregroundColor(Theme.gray4)
            
            Spacer()
            
            // カレンダーサイズ切り替え
            Button(action: toggleCalendarSize) {
                Image(systemName: calendarSize.icon)
                    .font(.caption)
                    .foregroundColor(Theme.primary)
            }
        }
    }
    
    // MARK: - Selected Date Details
    private var selectedDateDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダー
            HStack {
                Text(selectedDateText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text("\(selectedRecords.count)件")
                    .font(.subheadline)
                    .foregroundColor(Theme.gray5)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // スクロール可能なレコードリスト
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(selectedRecords, id: \.id) { record in
                        CalendarRecordRow(
                            record: record,
                            onTap: { onRecordTap(record) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .frame(maxHeight: 300) // 最大高さを制限してスクロールを促進
            .refreshable {
                await viewModel.loadDataAsync()
            }
        }
        .background(Color.white)
        .cornerRadius(Constants.UI.cornerRadius)
        .shadow(color: Theme.shadowColor, radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // MARK: - Selected Date Details (Full Height)
    private var selectedDateDetailsFullHeight: some View {
        VStack(alignment: .leading, spacing: 12) {
            // セクションヘッダー
            HStack {
                Text(selectedDateText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text("\(selectedRecords.count)件")
                    .font(.subheadline)
                    .foregroundColor(Theme.gray5)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // レコードリスト（スクロール無し、全て表示）
            LazyVStack(spacing: 8) {
                ForEach(selectedRecords, id: \.id) { record in
                    CalendarRecordRow(
                        record: record,
                        onTap: { onRecordTap(record) }
                    )
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
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(Theme.gray3)
            
            Text("この日は記録がありません")
                .font(.subheadline)
                .foregroundColor(Theme.gray5)
            
            Text("タップで記録を作成できます")
                .font(.caption)
                .foregroundColor(Theme.gray4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.5))
        .cornerRadius(Constants.UI.cornerRadius)
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.shortWeekdaySymbols.map { String($0.prefix(1)) }
    }
    
    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let startOfMonth = monthInterval.start
        let endOfMonth = calendar.date(byAdding: DateComponents(day: -1), to: monthInterval.end)!
        
        // 月の最初の週の日曜日から開始
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        // 月の最後の週の土曜日まで
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: endOfMonth)?.end ?? endOfMonth
        
        var days: [Date] = []
        var currentDate = startOfWeek
        
        while currentDate < endOfWeek {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private var currentMonthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: currentMonth)
    }
    
    private var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
    
    private var recordsInCurrentMonth: [Record] {
        return viewModel.filteredRecords.filter { record in
            calendar.isDate(record.createdAt, equalTo: currentMonth, toGranularity: .month)
        }
    }
    
    private var activeDaysInMonth: Int {
        let uniqueDays = Set(recordsInCurrentMonth.map { 
            calendar.startOfDay(for: $0.createdAt) 
        })
        return uniqueDays.count
    }
    
    private var currentStreak: Int {
        // 連続記録日数の計算（簡易版）
        let today = Date()
        var streak = 0
        var checkDate = calendar.startOfDay(for: today)
        
        while true {
            let recordsForDay = viewModel.filteredRecords.filter { 
                calendar.isDate($0.createdAt, inSameDayAs: checkDate) 
            }
            
            if recordsForDay.isEmpty {
                break
            }
            
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            
            // 最大100日まで
            if streak >= 100 { break }
        }
        
        return streak
    }
    
    private var maxRecordsInMonth: Int {
        let dailyRecordCounts = Dictionary(grouping: recordsInCurrentMonth) { record in
            calendar.startOfDay(for: record.createdAt)
        }.mapValues { $0.count }
        
        return dailyRecordCounts.values.max() ?? 0
    }
    
    // MARK: - Helper Functions
    private func recordsForDate(_ date: Date) -> [Record] {
        return viewModel.filteredRecords.filter { record in
            calendar.isDate(record.createdAt, inSameDayAs: date)
        }
    }
    
    private func heatmapColor(for recordCount: Int, maxIntensity: Int) -> Color {
        let intensity = Double(recordCount) / Double(maxIntensity)
        
        switch intensity {
        case 0:
            return Theme.gray1
        case 0..<0.25:
            return Theme.primary.opacity(0.2)
        case 0.25..<0.5:
            return Theme.primary.opacity(0.4)
        case 0.5..<0.75:
            return Theme.primary.opacity(0.6)
        default:
            return Theme.primary.opacity(0.8)
        }
    }
    
    // MARK: - Actions
    private func previousMonth() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func selectDate(_ date: Date) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = date
        }
    }
    
    private func updateSelectedRecords() {
        selectedRecords = recordsForDate(selectedDate).sorted { 
            $0.createdAt > $1.createdAt 
        }
    }
    
    private func toggleCalendarSize() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            calendarSize = calendarSize == .standard ? .compact : .standard
        }
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let recordCount: Int
    let isSelected: Bool
    let isCurrentMonth: Bool
    let maxRecordsInMonth: Int
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 背景（ヒートマップ）
                Rectangle()
                    .fill(heatmapBackgroundColor)
                    .frame(height: 32)
                
                // 選択状態のオーバーレイ
                if isSelected {
                    Rectangle()
                        .stroke(Theme.primary, lineWidth: 2)
                        .frame(height: 32)
                }
                
                // 日付テキスト
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(textColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .cornerRadius(4)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
    
    private var heatmapBackgroundColor: Color {
        guard isCurrentMonth else { return Theme.gray1.opacity(0.3) }
        
        if recordCount == 0 {
            return Theme.gray1
        }
        
        let intensity = Double(recordCount) / Double(max(maxRecordsInMonth, 1))
        
        switch intensity {
        case 0..<0.25:
            return Theme.primary.opacity(0.2)
        case 0.25..<0.5:
            return Theme.primary.opacity(0.4)
        case 0.5..<0.75:
            return Theme.primary.opacity(0.6)
        default:
            return Theme.primary.opacity(0.8)
        }
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return Theme.gray4.opacity(0.5)
        }
        
        let intensity = Double(recordCount) / Double(max(maxRecordsInMonth, 1))
        return intensity > 0.5 ? .white : Theme.text
    }
}

// MARK: - Calendar Record Row
struct CalendarRecordRow: View {
    let record: Record
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            HStack(spacing: 12) {
                // アイコン
                Image(systemName: record.type.systemImage)
                    .font(.title3)
                    .foregroundColor(Theme.primary)
                    .frame(width: 24)
                
                // 情報
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    
                    Text(formattedTime(record.createdAt))
                        .font(.caption)
                        .foregroundColor(Theme.gray5)
                }
                
                Spacer()
                
                // 長さ表示
                if let duration = record.formattedDuration {
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(Theme.gray4)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Theme.gray2)
                        )
                }
                
                // 矢印
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.gray4)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Theme.gray1.opacity(0.5))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(Theme.gray5)
        }
    }
}

// MARK: - Supporting Types
enum CalendarSize {
    case standard
    case compact
    
    var icon: String {
        switch self {
        case .standard: return "minus.magnifyingglass"
        case .compact: return "plus.magnifyingglass"
        }
    }
}