import Foundation
import Combine

// MARK: - Overall Stats
struct OverallStats {
    let totalRecordCount: Int
    let monthlyRecordCount: Int
    let totalDuration: TimeInterval
    let mostUsedType: RecordType?
    
    static let empty = OverallStats(
        totalRecordCount: 0,
        monthlyRecordCount: 0,
        totalDuration: 0,
        mostUsedType: nil
    )
}

// MARK: - Home ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    @Published var overallStats: OverallStats = .empty
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
                try await loadOverallStats()
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
            try await loadOverallStats()
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
    
    // MARK: - Record Creation from Photos
    func createRecordFromPhotoData(_ data: Data, isVideo: Bool) async throws {
        // 一時ファイルを作成
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "imported_\(Date().timeIntervalSince1970).\(isVideo ? "mp4" : "jpg")"
        let tempURL = tempDirectory.appendingPathComponent(fileName)
        
        // データを一時ファイルに書き込み
        try data.write(to: tempURL)
        
        // 記録タイプを決定
        let recordType: RecordType = isVideo ? .video : .image
        
        // CreateRecordUseCaseを使用して記録を作成
        let _ = try await createRecordUseCase.execute(
            type: recordType,
            fileURL: tempURL,
            duration: nil, // 写真の場合はnull
            title: "ライブラリから追加",
            tags: []
        )
        
        // 統計を再読み込み
        await loadDataAsync()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 新しい記録が保存された時の通知を監視
        NotificationCenter.default.publisher(for: .recordSaved)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    // 統計データを即座に再読み込み
                    await self?.loadDataAsync()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadOverallStats() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // 全期間の記録を取得
        let allRecords = try await getRecordsUseCase.execute(
            filter: RecordFilter(
                sortBy: .createdAt,
                sortOrder: .descending
            )
        )
        
        // 今月の開始日を取得
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return
        }
        
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        
        // 今月の記録を取得
        let monthlyRecords = try await getRecordsUseCase.execute(
            filter: RecordFilter(
                dateRange: monthStart...monthEnd,
                sortBy: .createdAt,
                sortOrder: .ascending
            )
        )
        
        let stats = calculateOverallStats(from: allRecords, monthlyRecords: monthlyRecords)
        
        await MainActor.run {
            self.overallStats = stats
        }
    }
    
    private func calculateOverallStats(from allRecords: [Record], monthlyRecords: [Record]) -> OverallStats {
        let totalRecordCount = allRecords.count
        let monthlyRecordCount = monthlyRecords.count
        
        // 総時間の計算
        let totalDuration = allRecords.compactMap { $0.duration }.reduce(0, +)
        
        // 最も使用されたタイプ
        let typeCounts = Dictionary(grouping: allRecords, by: { $0.type })
            .mapValues { $0.count }
        let mostUsedType = typeCounts.max(by: { $0.value < $1.value })?.key
        
        return OverallStats(
            totalRecordCount: totalRecordCount,
            monthlyRecordCount: monthlyRecordCount,
            totalDuration: totalDuration,
            mostUsedType: mostUsedType
        )
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
        dateRange: ClosedRange<Date>? = nil,
        searchText: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        sortBy: SortBy = .createdAt,
        sortOrder: SortOrder = .descending
    ) {
        self.types = types
        self.tags = tags
        self.dateRange = dateRange
        self.searchText = searchText
        self.limit = limit
        self.offset = offset
        self.sortBy = sortBy
        self.sortOrder = sortOrder
    }
}