import SwiftUI

struct RecordsView: View {
    @ObservedObject var viewModel: RecordsViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var showingSearchFilters = false
    @State private var showingDeleteConfirmation = false
    @State private var showingBulkActions = false
    @State private var selectedViewMode: RecordViewMode = .timeline
    
    var body: some View {
        NavigationStack {
            ZStack {
                // メインコンテンツエリア
                mainContentArea
                    .background(Theme.background)
                
            }
            .navigationTitle(viewModel.isSelectionMode ? viewModel.selectionStatusText : "記録")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isSelectionMode {
                        selectionToolbar
                    } else {
                        normalToolbar
                    }
                }
                
                if viewModel.isSelectionMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            viewModel.exitSelectionMode()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSearchFilters) {
                SearchFiltersView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingBulkActions) {
                BulkActionsView(viewModel: viewModel)
            }
            .confirmationDialog(
                "\(viewModel.selectedRecords.count)件の記録を削除しますか？",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    Task {
                        await viewModel.deleteSelectedRecords()
                    }
                }
                Button("キャンセル", role: .cancel) { }
            }
            // 削除エラーアラート
            .alert("削除エラー", isPresented: .constant(viewModel.deletionError != nil)) {
                Button("OK") {
                    viewModel.deletionError = nil
                }
            } message: {
                Text(viewModel.deletionError?.localizedDescription ?? "")
            }
            // 削除中プログレス表示
            .overlay(alignment: .center) {
                if viewModel.isDeletingRecords {
                    deletionProgressView
                }
            }
            .onAppear {
                viewModel.loadData()
            }
            .refreshable {
                await viewModel.loadDataAsync()
            }
        }
    }
    
    // MARK: - Main Content Area
    private var mainContentArea: some View {
        VStack(spacing: 0) {
            // 表示モード選択
            viewModeSelector
            
            // 検索バー
            searchBar
            
            // アクティブフィルター表示
            if viewModel.hasActiveFilters {
                activeFiltersView
            }
            
            // メインコンテンツ
            recordsContent
        }
    }
    
    // MARK: - View Mode Selector
    private var viewModeSelector: some View {
        Picker("表示モード", selection: $selectedViewMode) {
            Text("タイムライン").tag(RecordViewMode.timeline)
            Text("カレンダー").tag(RecordViewMode.calendar)
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
        .onChange(of: selectedViewMode) { oldValue, newValue in
            // インタラクティブフィードバック
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // ビューモード変更の処理
            viewModel.changeViewMode(to: newValue)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.gray4)
                
                TextField("記録を検索", text: Binding(
                    get: { viewModel.searchFilterState.searchText },
                    set: { viewModel.updateSearchText($0) }
                ))
                .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchFilterState.searchText.isEmpty {
                    Button(action: { viewModel.updateSearchText("") }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.gray4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.gray1)
            .cornerRadius(10)
            
            Button(action: { showingSearchFilters = true }) {
                Image(systemName: viewModel.hasActiveFilters ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                    .foregroundColor(viewModel.hasActiveFilters ? Theme.primary : Theme.gray4)
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - Active Filters View
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedType = viewModel.searchFilterState.selectedType {
                    FilterChip(
                        text: selectedType.displayName,
                        icon: selectedType.systemImage
                    ) {
                        viewModel.updateTypeFilter(nil)
                    }
                }
                
                ForEach(Array(viewModel.searchFilterState.selectedTags), id: \.id) { tag in
                    FilterChip(
                        text: tag.name,
                        icon: "tag.fill"
                    ) {
                        var newTags = viewModel.searchFilterState.selectedTags
                        newTags.remove(tag)
                        viewModel.updateTagsFilter(newTags)
                    }
                }
                
                
                Button("すべてクリア") {
                    viewModel.clearFilters()
                }
                .font(.caption)
                .foregroundColor(Theme.primary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
        .background(Theme.gray1)
    }
    
    // MARK: - Records Content
    private var recordsContent: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.filteredRecords.isEmpty {
                emptyStateView
            } else {
                switch selectedViewMode {
                case .timeline:
                    TimelineRecordsView(
                        viewModel: viewModel,
                        onRecordTap: handleRecordTap
                    )
                case .calendar:
                    CalendarRecordsView(
                        viewModel: viewModel,
                        onRecordTap: handleRecordTap
                    )
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("記録を読み込み中...")
                .foregroundColor(Theme.gray5)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(Theme.gray4)
            
            Text("記録がありません")
                .font(.headline)
                .foregroundColor(Theme.text)
            
            Text(viewModel.hasActiveFilters ? 
                "検索条件に一致する記録が見つかりませんでした" : 
                "記録を作成してみましょう")
                .font(.subheadline)
                .foregroundColor(Theme.gray5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    
    // MARK: - Toolbars
    private var normalToolbar: some View {
        HStack {
            if !viewModel.records.isEmpty {
                Button("選択") {
                    viewModel.enterSelectionMode()
                }
            }
        }
    }
    
    private var selectionToolbar: some View {
        HStack(spacing: 16) {
            // 削除ボタン（危険なアクションなので分離）
            Button(action: { 
                showingDeleteConfirmation = true 
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .disabled(!viewModel.canDelete)
            
            // その他アクション
            Menu {
                Button(action: { viewModel.selectAll() }) {
                    Label("すべて選択", systemImage: "checkmark.circle")
                }
                .disabled(viewModel.isDeletingRecords)
                
                Button(action: { viewModel.deselectAll() }) {
                    Label("選択解除", systemImage: "circle")
                }
                .disabled(viewModel.isDeletingRecords)
                
                Divider()
                
                Button(action: { showingBulkActions = true }) {
                    Label("一括操作", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel.selectedRecords.isEmpty || viewModel.isDeletingRecords)
                
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .disabled(viewModel.isDeletingRecords)
        }
    }
    
    // MARK: - Actions
    private func handleRecordTap(_ record: Record) {
        if viewModel.isSelectionMode {
            viewModel.toggleRecordSelection(record.id)
        } else {
            appCoordinator.showRecordDetail(record)
        }
    }
    
    // MARK: - Deletion Progress View
    private var deletionProgressView: some View {
        VStack(spacing: 16) {
            ProgressView(value: viewModel.deletionProgress)
                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                .scaleEffect(1.5)
            
            Text(viewModel.selectionStatusText)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("削除をキャンセルできません")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .frame(maxWidth: 280)
    }
}

// MARK: - Record Thumbnail Card
struct RecordThumbnailCard: View {
    let record: Record
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // サムネイル
                ZStack {
                    RoundedRectangle(cornerRadius: Constants.UI.smallCornerRadius)
                        .fill(Theme.gray2)
                        .frame(height: 120)
                        .overlay(
                            Group {
                                if let thumbnailURL = record.thumbnailURL,
                                   let imageData = try? Data(contentsOf: thumbnailURL),
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.smallCornerRadius))
                                } else {
                                    Image(systemName: record.type.systemImage)
                                        .font(.title)
                                        .foregroundColor(Theme.gray4)
                                }
                            }
                        )
                    
                    // 選択インジケーター（常に表示、選択モードでのみ見える）
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(isSelectionMode && isSelected ? Theme.primary : (isSelectionMode ? Color.white : Theme.background))
                                    .frame(width: 22, height: 22)
                                
                                Circle()
                                    .stroke(
                                        isSelectionMode ? (isSelected ? Theme.primary : Theme.gray4) : Theme.background, 
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 22, height: 22)
                                
                                if isSelectionMode && isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .font(.system(size: 10, weight: .bold))
                                }
                            }
                            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 0.5)
                            .opacity(isSelectionMode ? 1.0 : 0.0)
                            .scaleEffect(isSelectionMode ? 1.0 : 0.8)
                            .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
                        }
                        Spacer()
                    }
                    .padding(6)
                    
                    // 録画時間表示（動画・音声の場合）
                    if let duration = record.formattedDuration {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(duration)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(8)
                    }
                }
                
                // 記録情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.formattedDate)
                        .font(.caption2)
                        .foregroundColor(Theme.gray5)
                    
                    Text(record.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                    
                    // タグ表示
                    if !record.tags.isEmpty {
                        HStack {
                            ForEach(Array(record.tags.prefix(2)), id: \.id) { tag in
                                Text(tag.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.primary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Theme.primary.opacity(0.1))
                                    .cornerRadius(3)
                            }
                            
                            if record.tags.count > 2 {
                                Text("+\(record.tags.count - 2)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.gray4)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            isSelectionMode && isSelected ?
            Theme.primary.opacity(0.05) :
            Color.white
        )
        .cornerRadius(Constants.UI.cornerRadius)
        .overlay(
            isSelectionMode && isSelected ?
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(Theme.primary, lineWidth: 2)
            : nil
        )
        .shadow(
            color: isSelectionMode && isSelected ? Theme.primary.opacity(0.2) : Theme.shadowColor,
            radius: isSelectionMode && isSelected ? 6 : 2,
            x: 0,
            y: 2
        )
        .scaleEffect(isSelectionMode && isSelected ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Supporting Types
enum RecordViewMode: String, CaseIterable {
    case timeline = "timeline"
    case calendar = "calendar"
    
    var displayName: String {
        switch self {
        case .timeline:
            return "タイムライン"
        case .calendar:
            return "カレンダー"
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let text: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .foregroundColor(Theme.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.primary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Search Filters View
struct SearchFiltersView: View {
    @ObservedObject var viewModel: RecordsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // タイプフィルター
                Section("記録タイプ") {
                    Picker("タイプ", selection: Binding(
                        get: { viewModel.searchFilterState.selectedType },
                        set: { viewModel.updateTypeFilter($0) }
                    )) {
                        Text("すべて").tag(RecordType?.none)
                        ForEach(RecordType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(RecordType?.some(type))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                
                // ソート設定
                Section("並び順") {
                    Picker("並び順", selection: Binding(
                        get: { viewModel.searchFilterState.sortBy },
                        set: { sortBy in
                            viewModel.updateSorting(by: sortBy, order: viewModel.searchFilterState.sortOrder)
                        }
                    )) {
                        Text("作成日時").tag(SearchFilterState.SortBy.createdAt)
                        Text("更新日時").tag(SearchFilterState.SortBy.updatedAt)
                        Text("再生時間").tag(SearchFilterState.SortBy.duration)
                        Text("名前").tag(SearchFilterState.SortBy.name)
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("順序", selection: Binding(
                        get: { viewModel.searchFilterState.sortOrder },
                        set: { sortOrder in
                            viewModel.updateSorting(by: viewModel.searchFilterState.sortBy, order: sortOrder)
                        }
                    )) {
                        Text("降順").tag(SearchFilterState.SortOrder.descending)
                        Text("昇順").tag(SearchFilterState.SortOrder.ascending)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("検索・フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("リセット") {
                        viewModel.clearFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bulk Actions View
struct BulkActionsView: View {
    @ObservedObject var viewModel: RecordsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    
                    Button {
                        viewModel.showingTagEditor = true
                        dismiss()
                    } label: {
                        Label("タグを追加", systemImage: "tag")
                    }
                } header: {
                    Text("選択した\(viewModel.selectedRecords.count)件の記録")
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("一括操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "選択した記録を削除しますか？",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    Task {
                        try await viewModel.deleteSelectedRecords()
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) { }
            }
        }
    }
}