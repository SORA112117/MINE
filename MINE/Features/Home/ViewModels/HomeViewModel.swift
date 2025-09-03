import Foundation
import Combine

// MARK: - Weekly Stats
struct WeeklyStats {
    let recordCount: Int
    let streakDays: Int
    let totalDuration: TimeInterval
    let mostUsedType: RecordType?
    
    static let empty = WeeklyStats(
        recordCount: 0,
        streakDays: 0,
        totalDuration: 0,
        mostUsedType: nil
    )
}

// MARK: - Home ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    @Published var recentRecords: [Record] = []
    @Published var weeklyStats: WeeklyStats = .empty
    @Published var isLoading = false
    @Published var error: Error?
    
    private let getRecordsUseCase: GetRecordsUseCase
    private let createRecordUseCase: CreateRecordUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(
        getRecordsUseCase: GetRecordsUseCase,
        createRecordUseCase: CreateRecordUseCase
    ) {
        self.getRecordsUseCase = getRecordsUseCase
        self.createRecordUseCase = createRecordUseCase
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadData() {
        Task {
            do {
                try await loadRecentRecords()
                try await loadWeeklyStats()
            } catch {
                handleError(error)
            }
        }
    }
    
    @MainActor
    func loadDataAsync() async {
        isLoading = true
        error = nil
        
        do {
            try await loadRecentRecords()
            try await loadWeeklyStats()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refreshData() {
        Task {
            await loadDataAsync()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 必要に応じて追加のバインディング
    }
    
    private func loadRecentRecords() async throws {
        let records = try await getRecordsUseCase.execute(
            filter: RecordFilter(
                limit: 10,
                sortBy: .createdAt,
                sortOrder: .descending
            )
        )
        
        await MainActor.run {
            self.recentRecords = records
        }
    }
    
    private func loadWeeklyStats() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // 今週の開始日を取得
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return
        }
        
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now
        
        let weeklyRecords = try await getRecordsUseCase.execute(
            filter: RecordFilter(
                dateRange: weekStart...weekEnd,
                sortBy: .createdAt,
                sortOrder: .ascending
            )
        )
        
        let stats = calculateWeeklyStats(from: weeklyRecords, startDate: weekStart)
        
        await MainActor.run {
            self.weeklyStats = stats
        }
    }
    
    private func calculateWeeklyStats(from records: [Record], startDate: Date) -> WeeklyStats {
        let recordCount = records.count
        
        // 継続日数の計算
        let streakDays = calculateStreakDays(from: records, startDate: startDate)
        
        // 総時間の計算
        let totalDuration = records.compactMap { $0.duration }.reduce(0, +)
        
        // 最も使用されたタイプ
        let typeCounts = Dictionary(grouping: records, by: { $0.type })
            .mapValues { $0.count }
        let mostUsedType = typeCounts.max(by: { $0.value < $1.value })?.key
        
        return WeeklyStats(
            recordCount: recordCount,
            streakDays: streakDays,
            totalDuration: totalDuration,
            mostUsedType: mostUsedType
        )
    }
    
    private func calculateStreakDays(from records: [Record], startDate: Date) -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        // 日付ごとに記録をグループ化
        let recordsByDate = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.createdAt)
        }
        
        var streakDays = 0
        var currentDate = calendar.startOfDay(for: today)
        
        // 今日から遡って連続日数をカウント
        while currentDate >= startDate {
            if recordsByDate[currentDate] != nil {
                streakDays += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? startDate
            } else {
                break
            }
        }
        
        return streakDays
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        self.error = error
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - Record Filter
struct RecordFilter {
    let types: [RecordType]?
    let tags: [Tag]?
    let folderId: UUID?
    let dateRange: ClosedRange<Date>?
    let searchText: String?
    let limit: Int?
    let offset: Int?
    let sortBy: SortBy
    let sortOrder: SortOrder
    
    enum SortBy {
        case createdAt
        case updatedAt
        case duration
        case name
    }
    
    enum SortOrder {
        case ascending
        case descending
    }
    
    init(
        types: [RecordType]? = nil,
        tags: [Tag]? = nil,
        folderId: UUID? = nil,
        dateRange: ClosedRange<Date>? = nil,
        searchText: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        sortBy: SortBy = .createdAt,
        sortOrder: SortOrder = .descending
    ) {
        self.types = types
        self.tags = tags
        self.folderId = folderId
        self.dateRange = dateRange
        self.searchText = searchText
        self.limit = limit
        self.offset = offset
        self.sortBy = sortBy
        self.sortOrder = sortOrder
    }
}