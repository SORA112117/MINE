import SwiftUI

struct FolderPickerView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        List {
            Text("フォルダ選択画面（実装予定）")
                .foregroundColor(Theme.gray5)
                .padding()
        }
        .navigationTitle("フォルダ選択")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完了") {
                    appCoordinator.dismissSheet()
                }
            }
        }
    }
}

struct TagEditorView: View {
    let selectedTags: Set<Tag>
    let onTagsUpdated: (Set<Tag>) -> Void
    
    @StateObject private var viewModel: TagEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var workingTags: Set<Tag>
    @State private var showingNewTagAlert = false
    @State private var newTagName = ""
    @State private var newTagColor = "#4A90A4"
    
    init(selectedTags: Set<Tag>, onTagsUpdated: @escaping (Set<Tag>) -> Void, manageTagsUseCase: ManageTagsUseCase) {
        self.selectedTags = selectedTags
        self.onTagsUpdated = onTagsUpdated
        self._workingTags = State(initialValue: selectedTags)
        self._viewModel = StateObject(wrappedValue: TagEditorViewModel(manageTagsUseCase: manageTagsUseCase))
    }
    
    private let availableColors = [
        "#4A90A4", "#F4A261", "#67B3A3", "#52C41A", 
        "#F5222D", "#FAAD14", "#722ED1", "#13C2C2"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                searchBar
                
                // 選択中タグ表示
                if !workingTags.isEmpty {
                    selectedTagsSection
                }
                
                // 利用可能タグ一覧
                if viewModel.isLoading {
                    loadingView
                } else {
                    availableTagsList
                }
            }
            .navigationTitle("タグ編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("新規作成") {
                        showingNewTagAlert = true
                    }
                    .font(.subheadline)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        onTagsUpdated(workingTags)
                        dismiss()
                    }
                }
            }
            .alert("新しいタグ", isPresented: $showingNewTagAlert) {
                TextField("タグ名", text: $newTagName)
                    .textInputAutocapitalization(.words)
                
                Button("作成") {
                    Task {
                        await viewModel.createTag(name: newTagName, color: newTagColor)
                        newTagName = ""
                        newTagColor = "#4A90A4"
                    }
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button("キャンセル", role: .cancel) {
                    newTagName = ""
                    newTagColor = "#4A90A4"
                }
            } message: {
                Text("タグ名を入力してください")
            }
            .onAppear {
                Task {
                    await viewModel.loadTags()
                }
            }
        }
    }
    
    // MARK: - 検索バー
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.gray4)
                    .font(.subheadline)
                
                TextField("タグを検索", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.gray4)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.gray1)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // MARK: - 選択中タグセクション
    private var selectedTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("選択中 \(workingTags.count)") 
                    .font(.headline)
                    .foregroundColor(Theme.text)
                Spacer()
                Button("すべて解除") {
                    workingTags.removeAll()
                }
                .font(.caption)
                .foregroundColor(Theme.primary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(workingTags), id: \.id) { tag in
                        Button {
                            workingTags.remove(tag)
                        } label: {
                            HStack(spacing: 4) {
                                Text(tag.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tag.swiftUIColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Theme.gray1)
    }
    
    // MARK: - ローディングビュー
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("タグを読み込み中...")
                .font(.subheadline)
                .foregroundColor(Theme.gray5)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 利用可能タグ一覧
    private var availableTagsList: some View {
        List {
            ForEach(viewModel.filteredTags, id: \.id) { tag in
                TagRowView(
                    tag: tag,
                    isSelected: workingTags.contains(tag),
                    onToggle: {
                        if workingTags.contains(tag) {
                            workingTags.remove(tag)
                        } else {
                            workingTags.insert(tag)
                        }
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - タグ行ビュー
struct TagRowView: View {
    let tag: Tag
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                // タグ色インジケーター
                Circle()
                    .fill(tag.swiftUIColor)
                    .frame(width: 24, height: 24)
                
                // タグ情報
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.name)
                        .font(.headline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? Theme.primary : Theme.text)
                    
                    Text("使用回数: \(tag.usageCount) 回")
                        .font(.caption)
                        .foregroundColor(Theme.gray5)
                }
                
                Spacer()
                
                // 選択インジケーター
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Theme.primary : Theme.gray4)
                    .font(.title3)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - TagEditorViewModel
@MainActor
class TagEditorViewModel: ObservableObject {
    @Published var tags: [Tag] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var error: Error?
    
    private let manageTagsUseCase: ManageTagsUseCase
    
    init(manageTagsUseCase: ManageTagsUseCase) {
        self.manageTagsUseCase = manageTagsUseCase
    }
    
    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return tags.sorted { 
                if $0.usageCount == $1.usageCount {
                    return $0.name.lowercased() < $1.name.lowercased()
                }
                return $0.usageCount > $1.usageCount
            }
        } else {
            return tags.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }.sorted { 
                if $0.usageCount == $1.usageCount {
                    return $0.name.lowercased() < $1.name.lowercased()
                }
                return $0.usageCount > $1.usageCount
            }
        }
    }
    
    func loadTags() async {
        isLoading = true
        error = nil
        
        do {
            let loadedTags = try await manageTagsUseCase.getTags()
            tags = loadedTags
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func createTag(name: String, color: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        do {
            let newTag = try await manageTagsUseCase.createTag(
                name: trimmedName,
                color: color
            )
            tags.append(newTag)
        } catch {
            self.error = error
        }
    }
}

struct TemplateEditorView: View {
    let template: RecordTemplate?
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        List {
            Text("テンプレート編集画面（実装予定）")
                .foregroundColor(Theme.gray5)
                .padding()
        }
        .navigationTitle(template == nil ? "新規テンプレート" : "テンプレート編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    appCoordinator.dismissSheet()
                }
            }
        }
    }
}

struct SubscriptionView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        ScrollView {
            VStack(spacing: Constants.UI.padding) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.accent)
                    
                    Text("MINE Pro")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.text)
                    
                    Text("すべての機能を無制限で使用")
                        .font(.subheadline)
                        .foregroundColor(Theme.gray5)
                }
                .padding()
                
                // 機能比較
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        title: "動画記録",
                        freeVersion: "5秒まで",
                        proVersion: "5分まで"
                    )
                    
                    FeatureRow(
                        title: "音声記録",
                        freeVersion: "1分30秒まで",
                        proVersion: "無制限"
                    )
                    
                    FeatureRow(
                        title: "クラウドバックアップ",
                        freeVersion: "なし",
                        proVersion: "無制限"
                    )
                    
                    FeatureRow(
                        title: "連続記録",
                        freeVersion: "なし",
                        proVersion: "利用可能"
                    )
                }
                .padding()
                .background(Color.white)
                .cornerRadius(Constants.UI.cornerRadius)
                
                // 料金プラン
                VStack(spacing: 12) {
                    PlanCard(
                        title: "月額プラン",
                        price: Constants.Subscription.monthlyPrice,
                        period: "月"
                    )
                    
                    PlanCard(
                        title: "年額プラン",
                        price: Constants.Subscription.yearlyPrice,
                        period: "年",
                        badge: "17%お得"
                    )
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("MINE Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる") {
                    appCoordinator.dismissSheet()
                }
            }
        }
    }
}

struct FeatureRow: View {
    let title: String
    let freeVersion: String
    let proVersion: String
    
    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .foregroundColor(Theme.text)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(freeVersion)
                    .font(.caption)
                    .foregroundColor(Theme.gray5)
                
                Text(proVersion)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.primary)
            }
        }
    }
}

struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    
    init(title: String, price: String, period: String, badge: String? = nil) {
        self.title = title
        self.price = price
        self.period = period
        self.badge = badge
    }
    
    var body: some View {
        Button {
            // サブスクリプション購入処理（実装予定）
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Theme.text)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.accent)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text("\(price) / \(period)")
                        .font(.subheadline)
                        .foregroundColor(Theme.gray5)
                }
                
                Spacer()
                
                Text("選択")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.primary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(Theme.primary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}