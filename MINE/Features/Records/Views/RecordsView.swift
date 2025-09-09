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
            
            // 検索バー以下のコンテンツ（高度な人間工学的アニメーション）
            VStack(spacing: 0) {
                // アクティブフィルター表示（階層的遷移）
                if viewModel.hasActiveFilters {
                    activeFiltersView
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.hasActiveFilters)
                }
                
                // メインコンテンツ
                recordsContent
            }
            // 多軸同期アニメーション（人間工学的改善）
            .opacity(viewModel.isContentFading ? 0.3 : 1.0)
            .offset(
                x: viewModel.contentOffset, 
                y: viewModel.contentVerticalOffset
            )
            .scaleEffect(viewModel.contentScale)
            .blur(radius: viewModel.backgroundBlur)
            // 段階的アニメーション適用
            .animation(
                viewModel.currentAnimationPhase == .preparation ? 
                    .spring(response: 0.2, dampingFraction: 0.9) :
                viewModel.currentAnimationPhase == .fadeOut ?
                    .easeOut(duration: 0.4) :
                viewModel.currentAnimationPhase == .fadeIn ?
                    .spring(response: 0.6, dampingFraction: 0.8) :
                    .spring(response: 0.3, dampingFraction: 1.0),
                value: viewModel.isContentFading
            )
            .animation(
                .easeInOut(duration: 0.3),
                value: viewModel.contentOffset
            )
            .animation(
                .spring(response: 0.4, dampingFraction: 0.8),
                value: viewModel.contentScale
            )
            .animation(
                .easeOut(duration: 0.3),
                value: viewModel.backgroundBlur
            )
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
    
    // MARK: - Search Bar (視覚的階層改善版)
    private var searchBar: some View {
        HStack(spacing: 12) {
            // メイン検索フィールド（認知負荷軽減）
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(viewModel.searchFilterState.searchText.isEmpty ? Theme.gray4 : Theme.primary)
                    .font(.system(size: 16, weight: .medium))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.searchFilterState.searchText.isEmpty)
                
                TextField("記録を検索", text: Binding(
                    get: { viewModel.searchFilterState.searchText },
                    set: { viewModel.updateSearchText($0) }
                ))
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))
                
                // クリアボタン（アニメーション改善）
                if !viewModel.searchFilterState.searchText.isEmpty {
                    Button(action: { 
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        viewModel.updateSearchText("") 
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.gray4)
                            .font(.system(size: 16))
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.searchFilterState.searchText.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.gray1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                viewModel.searchFilterState.searchText.isEmpty ? Color.clear : Theme.primary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.searchFilterState.searchText.isEmpty)
            
            // フィルターボタン（視覚的重要度明確化）
            Button(action: { 
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showingSearchFilters = true 
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(viewModel.hasActiveFilters ? Theme.primary.opacity(0.15) : Theme.gray1)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    viewModel.hasActiveFilters ? Theme.primary : Color.clear,
                                    lineWidth: viewModel.hasActiveFilters ? 1.5 : 0
                                )
                        )
                    
                    Image(systemName: viewModel.hasActiveFilters ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                        .foregroundColor(viewModel.hasActiveFilters ? Theme.primary : Theme.gray4)
                        .font(.system(size: 18, weight: .medium))
                    
                    // アクティブフィルター数のバッジ
                    if viewModel.hasActiveFilters {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                            Spacer()
                        }
                        .frame(width: 44, height: 44)
                    }
                }
            }
            .scaleEffect(viewModel.hasActiveFilters ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.hasActiveFilters)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
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
        VStack(spacing: 20) {
            // 改善されたローディングアニメーション
            ZStack {
                Circle()
                    .stroke(Theme.gray2, lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .rotation3DEffect(
                        .degrees(360),
                        axis: (x: 0, y: 0, z: 1),
                        perspective: 1.0
                    )
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: viewModel.isLoading)
            }
            
            VStack(spacing: 8) {
                Text("記録を読み込み中...")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.text)
                
                Text("しばらくお待ちください")
                    .font(.caption)
                    .foregroundColor(Theme.gray5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // 認知負荷を軽減するアイコン（コンテキスト明確化）
            ZStack {
                Circle()
                    .fill(Theme.gray1)
                    .frame(width: 120, height: 120)
                
                Image(systemName: viewModel.hasActiveFilters ? "magnifyingglass" : "plus.circle")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(Theme.primary.opacity(0.7))
            }
            
            VStack(spacing: 12) {
                Text(viewModel.hasActiveFilters ? "該当する記録なし" : "記録がありません")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Text(viewModel.hasActiveFilters ? 
                    "検索条件を変更するか、\n新しい記録を作成してください" : 
                    "右上の＋ボタンから\n最初の記録を作成しましょう")
                    .font(.body)
                    .foregroundColor(Theme.gray5)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // アクション提案（認知負荷軽減）
            if viewModel.hasActiveFilters {
                Button("フィルターをクリア") {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    viewModel.clearFilters()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.primary.opacity(0.1))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
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
    
    // MARK: - Deletion Progress View (認知科学的改善版)
    private var deletionProgressView: some View {
        VStack(spacing: 20) {
            // アニメーション付きプログレス
            ZStack {
                Circle()
                    .stroke(Color.red.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: viewModel.deletionProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.deletionProgress)
                
                // 中央のアイコン（認知負荷軽減）
                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .scaleEffect(sin(Date().timeIntervalSince1970 * 3) * 0.1 + 1.0) // 微細な脈動効果
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.isDeletingRecords)
            }
            
            // 状態テキスト（階層明確化）
            VStack(spacing: 8) {
                Text("削除中...")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(Int(viewModel.deletionProgress * 100))% 完了")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                
                // プロセス説明（認知負荷軽減）
                Text("ファイルとデータを安全に削除しています")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(0.7)
            }
            
            // 進行状況バー（追加視覚情報）
            ProgressView(value: viewModel.deletionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                .scaleEffect(y: 2)
                .cornerRadius(4)
                .frame(width: 200)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(maxWidth: 320)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
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