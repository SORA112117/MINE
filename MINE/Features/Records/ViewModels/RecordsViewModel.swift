import Foundation
import Combine

// MARK: - Search Filter State
struct SearchFilterState {
    var searchText: String = ""
    var selectedType: RecordType?
    var selectedTags: Set<Tag> = []
    var dateRange: ClosedRange<Date>?
    var sortBy: SortBy = .createdAt
    var sortOrder: SortOrder = .descending
    
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
}

// MARK: - Deletion Error Types
enum DeletionError: LocalizedError {
    case partialFailure(succeeded: Int, failed: Int)
    case allFailed(count: Int)
    
    var errorDescription: String? {
        switch self {
        case .partialFailure(let succeeded, let failed):
            return "\(succeeded)件の記録を削除しましたが、\(failed)件の削除に失敗しました。"
        case .allFailed(let count):
            return "\(count)件の記録の削除にすべて失敗しました。"
        }
    }
}

// MARK: - Records ViewModel
@MainActor
class RecordsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var records: [Record] = []
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchFilterState = SearchFilterState()
    @Published var showingTagEditor = false
    @Published var selectedRecords: Set<UUID> = []
    @Published var isSelectionMode = false
    
    // MARK: - Use Cases
    private let getRecordsUseCase: GetRecordsUseCase
    private let deleteRecordUseCase: DeleteRecordUseCase
    private let manageTagsUseCase: ManageTagsUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Concurrency Control
    private var loadTask: Task<Void, Never>?
    private var hasInitialized = false
    
    init(
        getRecordsUseCase: GetRecordsUseCase,
        deleteRecordUseCase: DeleteRecordUseCase,
        manageTagsUseCase: ManageTagsUseCase
    ) {
        self.getRecordsUseCase = getRecordsUseCase
        self.deleteRecordUseCase = deleteRecordUseCase
        self.manageTagsUseCase = manageTagsUseCase
        
        setupBindings()
    }
    
    deinit {
        loadTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    func loadData() {
        // 初回のみ自動ロードを実行
        guard !hasInitialized else { return }
        hasInitialized = true
        
        // 既存の処理をキャンセルして新しい処理を開始
        loadTask?.cancel()
        loadTask = Task {
            await loadDataAsync()
        }
    }
    
    // データを強制的にリフレッシュ
    func refreshData() {
        loadTask?.cancel()
        loadTask = Task {
            await loadDataAsync()
        }
    }
    
    @MainActor
    func loadDataAsync() async {
        // 既にロード中の場合は重複実行を防ぐ
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            try await loadRecords()
            try await loadTags()
        } catch {
            // Task がキャンセルされた場合はエラーを設定しない
            if !Task.isCancelled {
                self.error = error
            }
        }
        
        isLoading = false
    }
    
    
    func forceLoadData() {
        // 強制的にデータを再読み込み（初期化フラグを無視）
        loadTask?.cancel()
        loadTask = Task {
            await loadDataAsync()
        }
    }
    
    // MARK: - Record Management
    
    func deleteRecord(_ record: Record) async throws {
        try await deleteRecordUseCase.execute(id: record.id)
        try await loadRecords()
    }
    
    // MARK: - Safe Deletion System
    @Published var isDeletingRecords = false
    @Published var deletionProgress: Double = 0.0
    @Published var deletionError: Error?
    
    func deleteSelectedRecords() async {
        // 削除中の状態管理
        await MainActor.run {
            isDeletingRecords = true
            deletionProgress = 0.0
            deletionError = nil
        }
        
        // 削除対象を一旦保存（selectedRecordsが変更される可能性があるため）
        let recordsToDelete = selectedRecords
        let totalCount = Double(recordsToDelete.count)
        
        guard totalCount > 0 else {
            await finishDeletion()
            return
        }
        
        // 削除実行（エラー処理付き）
        var deletedCount: Double = 0
        var failedDeletions: [UUID] = []
        
        for recordId in recordsToDelete {
            do {
                try await deleteRecordUseCase.execute(id: recordId)
                deletedCount += 1
                
                // プログレス更新
                await MainActor.run {
                    deletionProgress = deletedCount / totalCount
                }
                
                // 削除成功したIDを選択状態から除去
                await MainActor.run {
                    selectedRecords.remove(recordId)
                }
                
            } catch {
                failedDeletions.append(recordId)
                print("記録削除エラー ID: \(recordId), エラー: \(error)")
            }
        }
        
        // 削除完了後の処理
        await finishDeletion()
        
        // エラーがあった場合はユーザーに通知
        if !failedDeletions.isEmpty {
            await MainActor.run {
                deletionError = DeletionError.partialFailure(
                    succeeded: Int(deletedCount),
                    failed: failedDeletions.count
                )
            }
        }
    }
    
    @MainActor
    private func finishDeletion() {
        isDeletingRecords = false
        deletionProgress = 1.0
        
        // 削除が完了したら選択モード終了
        if selectedRecords.isEmpty {
            isSelectionMode = false
        }
        
        // データを再読み込み
        loadData()
    }
    
    
    func addTagsToRecords(_ tags: [Tag]) async throws {
        // 選択された記録にタグを追加
        let tagsSet = Set(tags)
        
        for recordId in selectedRecords {
            if let recordIndex = records.firstIndex(where: { $0.id == recordId }) {
                var updatedRecord = records[recordIndex]
                
                // 既存のタグに新しいタグを追加（重複は自動的に除外される）
                let updatedTags = updatedRecord.tags.union(tagsSet)
                
                // Record構造体を更新（tags変更）
                let newRecord = Record(
                    id: updatedRecord.id,
                    type: updatedRecord.type,
                    createdAt: updatedRecord.createdAt,
                    updatedAt: Date(), // 更新日時を現在時刻に
                    duration: updatedRecord.duration,
                    fileURL: updatedRecord.fileURL,
                    thumbnailURL: updatedRecord.thumbnailURL,
                    title: updatedRecord.title,
                    tags: updatedTags, // タグを更新
                    templateId: updatedRecord.templateId
                )
                
                // TODO: 実際のUse Case実装時は以下のようになる
                // try await updateRecordUseCase.updateTags(recordId: recordId, tags: Array(updatedTags))
                
                // 一時的にローカル配列を更新
                records[recordIndex] = newRecord
            }
        }
        
        // タグの使用回数を更新（TODO: Use Caseで実装）
        for tag in tags {
            if let tagIndex = self.tags.firstIndex(where: { $0.id == tag.id }) {
                let updatedTag = Tag(
                    id: tag.id,
                    name: tag.name,
                    color: tag.color,
                    usageCount: tag.usageCount + selectedRecords.count
                )
                self.tags[tagIndex] = updatedTag
            }
        }
        
        selectedRecords.removeAll()
        isSelectionMode = false
        
        // UI更新のためのリフレッシュ
        await MainActor.run {
            objectWillChange.send()
        }
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for recordId: UUID) {
        if selectedRecords.contains(recordId) {
            selectedRecords.remove(recordId)
        } else {
            selectedRecords.insert(recordId)
        }
        // 選択数がゼロになっても選択モードを維持
    }
    
    func enterSelectionMode() {
        isSelectionMode = true
        selectedRecords.removeAll()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedRecords.removeAll()
    }
    
    // MARK: - Safe Selection System
    func selectAll() {
        guard !isDeletingRecords else { return }
        let availableRecords = filteredRecords.filter { record in
            // 削除中でない記録のみ選択可能
            !deletingRecordIds.contains(record.id)
        }
        selectedRecords = Set(availableRecords.map { $0.id })
    }
    
    func deselectAll() {
        guard !isDeletingRecords else { return }
        selectedRecords.removeAll()
    }
    
    func toggleRecordSelection(_ recordId: UUID) {
        guard !isDeletingRecords else { return }
        guard !deletingRecordIds.contains(recordId) else { return }
        
        if selectedRecords.contains(recordId) {
            selectedRecords.remove(recordId)
        } else {
            selectedRecords.insert(recordId)
        }
    }
    
    // 削除中の記録ID（UI用）
    @Published var deletingRecordIds: Set<UUID> = []
    
    // 選択状態のテキスト
    var selectionStatusText: String {
        if isDeletingRecords {
            let progress = Int(deletionProgress * 100)
            return "削除中... \(progress)%"
        } else {
            return "\(selectedRecords.count)件選択中"
        }
    }
    
    // 削除可能かどうか
    var canDelete: Bool {
        return !selectedRecords.isEmpty && !isDeletingRecords
    }
    
    // MARK: - Search & Filter
    
    func updateSearchText(_ text: String) {
        searchFilterState.searchText = text
        applyFilters()
    }
    
    func updateTypeFilter(_ type: RecordType?) {
        searchFilterState.selectedType = type
        applyFilters()
    }
    
    func updateTagsFilter(_ tags: Set<Tag>) {
        searchFilterState.selectedTags = tags
        applyFilters()
    }
    
    
    func updateDateRangeFilter(_ dateRange: ClosedRange<Date>?) {
        searchFilterState.dateRange = dateRange
        applyFilters()
    }
    
    func updateSorting(by sortBy: SearchFilterState.SortBy, order: SearchFilterState.SortOrder) {
        searchFilterState.sortBy = sortBy
        searchFilterState.sortOrder = order
        applyFilters()
    }
    
    func clearFilters() {
        searchFilterState = SearchFilterState()
        applyFilters()
    }
    
    // MARK: - Computed Properties
    
    var filteredRecords: [Record] {
        let filtered = records.filter { record in
            // テキスト検索
            if !searchFilterState.searchText.isEmpty {
                let searchLower = searchFilterState.searchText.lowercased()
                let matchesTitle = record.title.lowercased().contains(searchLower)
                let matchesTags = record.tags.contains { tag in
                    tag.name.lowercased().contains(searchLower)
                }
                
                if !matchesTitle && !matchesTags {
                    return false
                }
            }
            
            // タイプフィルター
            if let selectedType = searchFilterState.selectedType {
                if record.type != selectedType {
                    return false
                }
            }
            
            // タグフィルター
            if !searchFilterState.selectedTags.isEmpty {
                let recordTags = Set(record.tags)
                if searchFilterState.selectedTags.intersection(recordTags).isEmpty {
                    return false
                }
            }
            
            
            // 日付範囲フィルター
            if let dateRange = searchFilterState.dateRange {
                if !dateRange.contains(record.createdAt) {
                    return false
                }
            }
            
            return true
        }
        
        // ソート
        return filtered.sorted(by: { record1, record2 in
            let isAscending = searchFilterState.sortOrder == .ascending
            
            switch searchFilterState.sortBy {
            case .createdAt:
                return isAscending ? record1.createdAt < record2.createdAt : record1.createdAt > record2.createdAt
            case .updatedAt:
                return isAscending ? record1.updatedAt < record2.updatedAt : record1.updatedAt > record2.updatedAt
            case .duration:
                let duration1 = record1.duration ?? 0
                let duration2 = record2.duration ?? 0
                return isAscending ? duration1 < duration2 : duration1 > duration2
            case .name:
                let name1 = record1.title
                let name2 = record2.title
                return isAscending ? name1 < name2 : name1 > name2
            }
        })
    }
    
    var hasActiveFilters: Bool {
        return !searchFilterState.searchText.isEmpty ||
               searchFilterState.selectedType != nil ||
               !searchFilterState.selectedTags.isEmpty ||
               searchFilterState.dateRange != nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // リアルタイム検索のデバウンス
        $searchFilterState
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
        
        // 新しい記録が保存された通知を監視
        NotificationCenter.default.publisher(for: .recordSaved)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadRecords() async throws {
        let filter = createRecordFilter()
        let loadedRecords = try await getRecordsUseCase.execute(filter: filter)
        
        await MainActor.run {
            self.records = loadedRecords
        }
    }
    
    
    private func loadTags() async throws {
        let loadedTags = try await manageTagsUseCase.getTags()
        
        await MainActor.run {
            self.tags = loadedTags
        }
    }
    
    private func createRecordFilter() -> RecordFilter {
        return RecordFilter(
            types: searchFilterState.selectedType.map { [$0] },
            tags: Array(searchFilterState.selectedTags).isEmpty ? nil : Array(searchFilterState.selectedTags),
            dateRange: searchFilterState.dateRange,
            searchText: searchFilterState.searchText.isEmpty ? nil : searchFilterState.searchText,
            limit: nil,
            offset: nil,
            sortBy: convertSortBy(searchFilterState.sortBy),
            sortOrder: convertSortOrder(searchFilterState.sortOrder)
        )
    }
    
    private func convertSortBy(_ sortBy: SearchFilterState.SortBy) -> RecordFilter.SortBy {
        switch sortBy {
        case .createdAt:
            return .createdAt
        case .updatedAt:
            return .updatedAt
        case .duration:
            return .duration
        case .name:
            return .name
        }
    }
    
    private func convertSortOrder(_ sortOrder: SearchFilterState.SortOrder) -> RecordFilter.SortOrder {
        switch sortOrder {
        case .ascending:
            return .ascending
        case .descending:
            return .descending
        }
    }
    
    private func applyFilters() {
        // フィルタリング結果は filteredRecords computed property で処理される
        // 必要に応じて追加の処理をここに実装
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        self.error = error
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - New View Mode Support
    
    func changeViewMode(to mode: RecordViewMode) {
        // ビューモード変更時の処理
        // 必要に応じてデータの再読み込みや状態更新を実行
    }
    
    func changeTimeScale(to timeScale: TimeScale) {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeScale {
        case .week:
            // 直近の一週間（7日前から今日まで）
            if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                searchFilterState.dateRange = weekAgo...now
            }
            
        case .month:
            // 直近の一ヶ月（30日前から今日まで）
            if let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) {
                searchFilterState.dateRange = monthAgo...now
            }
            
        case .all:
            // 全期間（フィルタなし）
            searchFilterState.dateRange = nil
        }
        
        // フィルタ更新を通知
        applyFilters()
    }
    
    // MARK: - Sidebar Support（タグベース機能のみ）
    
    var availableTags: [Tag] {
        // 使用可能なタグリストを返す
        return tags
    }
    
    var selectedTags: Set<Tag> {
        return searchFilterState.selectedTags
    }
    
    func selectTag(_ tag: Tag) {
        var currentTags = searchFilterState.selectedTags
        if currentTags.contains(tag) {
            currentTags.remove(tag)
        } else {
            currentTags.insert(tag)
        }
        updateTagsFilter(currentTags)
    }
    
    func clearAllFilters() {
        clearFilters()
    }
    
}