import SwiftUI

// MARK: - Records Sidebar View
struct RecordsSidebarView: View {
    @ObservedObject var viewModel: RecordsViewModel
    let onFolderSelected: (Folder?) -> Void
    let onTagSelected: (Tag) -> Void
    
    @State private var expandedFolders: Set<UUID> = []
    @State private var showingNewFolderDialog = false
    @State private var newFolderName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            sidebarHeader
            
            // コンテンツ
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // 全ての記録セクション
                    allRecordsSection
                    
                    // フォルダセクション
                    foldersSection
                    
                    // タグセクション
                    tagsSection
                }
            }
            .background(Color.white)
        }
        .sheet(isPresented: $showingNewFolderDialog) {
            newFolderDialog
        }
    }
    
    // MARK: - Header
    private var sidebarHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("フィルター")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(Theme.gray2)
        }
        .background(Color.white)
    }
    
    // MARK: - All Records Section
    private var allRecordsSection: some View {
        SidebarItem(
            icon: "tray.full",
            title: "全ての記録",
            count: viewModel.records.count,
            isSelected: viewModel.selectedFolder == nil && viewModel.selectedTags.isEmpty,
            onTap: {
                // インタラクティブフィードバック
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                onFolderSelected(nil)
                viewModel.clearAllFilters()
            }
        )
        .padding(.bottom, 8)
    }
    
    // MARK: - Folders Section
    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // セクションヘッダー
            HStack {
                Text("フォルダ")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.gray5)
                
                Spacer()
                
                Button(action: { showingNewFolderDialog = true }) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundColor(Theme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // フォルダリスト
            ForEach(viewModel.rootFolders, id: \.id) { folder in
                FolderTreeView(
                    folder: folder,
                    level: 0,
                    selectedFolder: viewModel.selectedFolder,
                    expandedFolders: $expandedFolders,
                    onFolderSelected: { selectedFolder in
                        // インタラクティブフィードバック
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        onFolderSelected(selectedFolder)
                    }
                )
            }
        }
        .padding(.bottom, 16)
    }
    
    // MARK: - Tags Section
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // セクションヘッダー
            HStack {
                Text("タグ")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.gray5)
                
                Spacer()
                
                Text("\(viewModel.availableTags.count)")
                    .font(.caption)
                    .foregroundColor(Theme.gray4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // タグリスト
            ForEach(viewModel.availableTags.sorted { $0.usageCount > $1.usageCount }, id: \.id) { tag in
                SidebarItem(
                    icon: "tag.fill",
                    title: tag.name,
                    count: tag.usageCount,
                    isSelected: viewModel.selectedTags.contains(tag),
                    accentColor: Color(hex: tag.color),
                    onTap: {
                        // インタラクティブフィードバック
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        
                        onTagSelected(tag)
                    }
                )
            }
        }
    }
    
    // MARK: - New Folder Dialog
    private var newFolderDialog: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("フォルダ名", text: $newFolderName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("新規フォルダ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        showingNewFolderDialog = false
                        newFolderName = ""
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createNewFolder()
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
    
    // MARK: - Actions
    private func createNewFolder() {
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // インタラクティブフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                try await viewModel.createFolder(name: trimmedName)
                await MainActor.run {
                    showingNewFolderDialog = false
                    newFolderName = ""
                }
            } catch {
                // エラーハンドリング
                print("フォルダ作成エラー: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Sidebar Item Component
struct SidebarItem: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void
    
    init(
        icon: String,
        title: String,
        count: Int,
        isSelected: Bool,
        accentColor: Color = Theme.primary,
        onTap: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.accentColor = accentColor
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? accentColor : Theme.gray4)
                    .frame(width: 16, height: 16)
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? Theme.text : Theme.gray5)
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? accentColor : Theme.gray4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? accentColor.opacity(0.1) : Theme.gray2)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(isSelected ? accentColor.opacity(0.05) : Color.clear)
            )
            .overlay(
                Rectangle()
                    .fill(isSelected ? accentColor : Color.clear)
                    .frame(width: 3),
                alignment: .leading
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Folder Tree View
struct FolderTreeView: View {
    let folder: Folder
    let level: Int
    let selectedFolder: Folder?
    @Binding var expandedFolders: Set<UUID>
    let onFolderSelected: (Folder) -> Void
    
    private var isSelected: Bool {
        selectedFolder?.id == folder.id
    }
    
    private var isExpanded: Bool {
        expandedFolders.contains(folder.id)
    }
    
    private var hasSubfolders: Bool {
        !folder.subFolderIds.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // フォルダアイテム
            HStack(spacing: 0) {
                // インデント
                if level > 0 {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: CGFloat(level * 16))
                }
                
                // 展開/折りたたみボタン
                if hasSubfolders {
                    Button(action: toggleExpansion) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(Theme.gray4)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16, height: 16)
                }
                
                // フォルダ情報
                SidebarItem(
                    icon: "folder.fill",
                    title: folder.name,
                    count: folder.recordIds.count,
                    isSelected: isSelected,
                    accentColor: Color(hex: folder.color),
                    onTap: {
                        onFolderSelected(folder)
                    }
                )
            }
            
            // サブフォルダ（展開時）
            // 注意: 現在のFolderモデルではsubFoldersプロパティがないため、
            // 将来のバージョンでサブフォルダ機能を実装予定
            if isExpanded && hasSubfolders {
                // TODO: サブフォルダ表示の実装
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private func toggleExpansion() {
        // インタラクティブフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if isExpanded {
            expandedFolders.remove(folder.id)
        } else {
            expandedFolders.insert(folder.id)
        }
    }
}

