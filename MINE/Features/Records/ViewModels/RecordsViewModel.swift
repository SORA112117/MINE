import Foundation
import Combine

// MARK: - Search Filter State
struct SearchFilterState {
    var searchText: String = ""
    var selectedType: RecordType?
    var selectedTags: Set<Tag> = []
    var selectedFolder: Folder?
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

// MARK: - Records ViewModel
@MainActor
class RecordsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var records: [Record] = []
    @Published var folders: [Folder] = []
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchFilterState = SearchFilterState()
    @Published var showingFolderPicker = false
    @Published var showingTagEditor = false
    @Published var selectedRecords: Set<UUID> = []
    @Published var isSelectionMode = false
    
    // MARK: - Use Cases
    private let getRecordsUseCase: GetRecordsUseCase
    private let deleteRecordUseCase: DeleteRecordUseCase
    private let manageFoldersUseCase: ManageFoldersUseCase
    private let manageTagsUseCase: ManageTagsUseCase
    private var cancellables = Set<AnyCancellable>()
    
    init(
        getRecordsUseCase: GetRecordsUseCase,
        deleteRecordUseCase: DeleteRecordUseCase,
        manageFoldersUseCase: ManageFoldersUseCase,
        manageTagsUseCase: ManageTagsUseCase
    ) {
        self.getRecordsUseCase = getRecordsUseCase
        self.deleteRecordUseCase = deleteRecordUseCase
        self.manageFoldersUseCase = manageFoldersUseCase
        self.manageTagsUseCase = manageTagsUseCase
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadData() {
        Task {
            await loadDataAsync()
        }
    }
    
    @MainActor
    func loadDataAsync() async {
        isLoading = true
        error = nil
        
        do {
            try await loadRecords()
            try await loadFolders()
            try await loadTags()
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
    
    // MARK: - Record Management
    
    func deleteRecord(_ record: Record) async throws {
        try await deleteRecordUseCase.execute(id: record.id)
        try await loadRecords()
    }
    
    func deleteSelectedRecords() async throws {
        for recordId in selectedRecords {
            try await deleteRecordUseCase.execute(id: recordId)
        }
        selectedRecords.removeAll()
        isSelectionMode = false
        try await loadRecords()
    }
    
    func moveRecordsToFolder(_ folderId: UUID?) async throws {
        for _ in selectedRecords {
            // Record移動のロジック（Use Caseに追加が必要）
            // 現在は簡易実装
        }
        selectedRecords.removeAll()
        isSelectionMode = false
        try await loadRecords()
    }
    
    func addTagsToRecords(_ tags: [Tag]) async throws {
        for _ in selectedRecords {
            // RecordにTagを追加するロジック（Use Caseに追加が必要）
            // 現在は簡易実装
        }
        selectedRecords.removeAll()
        isSelectionMode = false
        try await loadRecords()
    }
    
    // MARK: - Selection Management
    
    func toggleSelection(for recordId: UUID) {
        if selectedRecords.contains(recordId) {
            selectedRecords.remove(recordId)
        } else {
            selectedRecords.insert(recordId)
        }
        
        if selectedRecords.isEmpty {
            isSelectionMode = false
        }
    }
    
    func enterSelectionMode() {
        isSelectionMode = true
        selectedRecords.removeAll()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedRecords.removeAll()
    }
    
    func selectAll() {
        selectedRecords = Set(filteredRecords.map { $0.id })
    }
    
    func deselectAll() {
        selectedRecords.removeAll()
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
    
    func updateFolderFilter(_ folder: Folder?) {
        searchFilterState.selectedFolder = folder
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
                let matchesComment = record.comment?.lowercased().contains(searchLower) ?? false
                let matchesTags = record.tags.contains { tag in
                    tag.name.lowercased().contains(searchLower)
                }
                
                if !matchesComment && !matchesTags {
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
                let recordTags = Set(record.tags ?? [])
                if searchFilterState.selectedTags.intersection(recordTags).isEmpty {
                    return false
                }
            }
            
            // フォルダフィルター
            if let selectedFolder = searchFilterState.selectedFolder {
                if record.folderId != selectedFolder.id {
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
        return filtered.sorted { record1, record2 in
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
                let name1 = record1.comment ?? ""
                let name2 = record2.comment ?? ""
                return isAscending ? name1 < name2 : name1 > name2
            }
        }
    }
    
    var hasActiveFilters: Bool {
        return !searchFilterState.searchText.isEmpty ||
               searchFilterState.selectedType != nil ||
               !searchFilterState.selectedTags.isEmpty ||
               searchFilterState.selectedFolder != nil ||
               searchFilterState.dateRange != nil
    }
    
    var selectionStatusText: String {
        if selectedRecords.isEmpty {
            return "項目を選択"
        } else {
            return "\(selectedRecords.count)件選択中"
        }
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
    }
    
    private func loadRecords() async throws {
        let filter = createRecordFilter()
        let loadedRecords = try await getRecordsUseCase.execute(filter: filter)
        
        await MainActor.run {
            self.records = loadedRecords
        }
    }
    
    private func loadFolders() async throws {
        let loadedFolders = try await manageFoldersUseCase.getFolders()
        
        await MainActor.run {
            self.folders = loadedFolders
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
            folderId: searchFilterState.selectedFolder?.id,
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
}