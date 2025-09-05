import SwiftUI

struct RecordDetailView: View {
    let record: Record
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var diContainer: DIContainer
    @StateObject private var viewModel: RecordDetailViewModel
    @State private var showingTagEditor = false
    
    init(record: Record) {
        self.record = record
        // 一時的にデフォルト実装を使用、あとでDIContainerから正しく取得
        self._viewModel = StateObject(wrappedValue: RecordDetailViewModel.placeholder(record: record))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.UI.padding) {
                // メディアプレビュー
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .fill(Theme.gray2)
                    .frame(height: 300)
                    .overlay(
                        VStack {
                            Image(systemName: record.type.systemImage)
                                .font(.system(size: 60))
                                .foregroundColor(Theme.gray4)
                            
                            Text(record.type.displayName)
                                .font(.headline)
                                .foregroundColor(Theme.gray5)
                                .padding(.top)
                        }
                    )
                
                // 記録情報
                VStack(alignment: .leading, spacing: Constants.UI.smallPadding) {
                    Text("記録情報")
                        .font(.headline)
                        .foregroundColor(Theme.text)
                    
                    HStack {
                        Text("作成日時:")
                        Spacer()
                        Text(record.formattedDate)
                    }
                    .foregroundColor(Theme.gray5)
                    
                    if let duration = record.formattedDuration {
                        HStack {
                            Text("長さ:")
                            Spacer()
                            Text(duration)
                        }
                        .foregroundColor(Theme.gray5)
                    }
                    
                    // フォルダ機能は削除済み
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("タイトル:")
                            .foregroundColor(Theme.gray5)
                        
                        Text(record.title)
                            .foregroundColor(Theme.text)
                            .padding()
                            .background(Theme.gray1)
                            .cornerRadius(Constants.UI.smallCornerRadius)
                    }
                    
                    // タグ表示と編集
                    tagsInfoView
                }
                .padding()
                .background(Color.white)
                .cornerRadius(Constants.UI.cornerRadius)
            }
            .padding()
        }
        .navigationTitle("記録詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("編集") {
                    // 編集モード切替（将来実装）
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる") {
                    appCoordinator.dismissSheet()
                }
            }
        }
        .sheet(isPresented: $showingTagEditor) {
            NavigationView {
                Text("タグエディター（実装予定）")
                    .navigationTitle("タグ編集")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("完了") {
                                showingTagEditor = false
                            }
                        }
                    }
            }
        }
    }
    
    
    // MARK: - タグ情報表示
    private var tagsInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("タグ:")
                    .foregroundColor(Theme.gray5)
                Spacer()
                Button(record.tags.isEmpty ? "追加" : "編集") {
                    showingTagEditor = true
                }
                .font(.caption)
                .foregroundColor(Theme.primary)
            }
            
            if record.tags.isEmpty {
                Button {
                    showingTagEditor = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.dashed")
                            .foregroundColor(Theme.gray4)
                        Text("タグを追加")
                            .font(.subheadline)
                            .foregroundColor(Theme.gray5)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.gray3, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 3),
                    spacing: 8
                ) {
                    ForEach(Array(record.tags), id: \.id) { tag in
                        TagChipView(
                            tag: tag,
                            showUsageCount: true
                        )
                    }
                }
            }
        }
    }
}

// MARK: - タグチップビュー
struct TagChipView: View {
    let tag: Tag
    let showUsageCount: Bool
    
    init(tag: Tag, showUsageCount: Bool = false) {
        self.tag = tag
        self.showUsageCount = showUsageCount
    }
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(tag.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if showUsageCount && tag.usageCount > 1 {
                    Text("\(tag.usageCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tag.swiftUIColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - RecordDetailViewModel
@MainActor
class RecordDetailViewModel: ObservableObject {
    @Published var record: Record
    @Published var isLoading = false
    @Published var error: Error?
    
    private let updateRecordUseCase: UpdateRecordUseCase
    private let manageTagsUseCase: ManageTagsUseCase
    
    init(
        record: Record,
        updateRecordUseCase: UpdateRecordUseCase,
        manageTagsUseCase: ManageTagsUseCase
    ) {
        self.record = record
        self.updateRecordUseCase = updateRecordUseCase
        self.manageTagsUseCase = manageTagsUseCase
    }
    
    static func placeholder(record: Record) -> RecordDetailViewModel {
        RecordDetailViewModel(
            record: record,
            updateRecordUseCase: UpdateRecordUseCase(
                recordRepository: RecordRepository(
                    localDataSource: LocalDataSource(coreDataStack: CoreDataStack.shared), 
                    cloudDataSource: CloudDataSource()
                ),
                manageTagsUseCase: ManageTagsUseCase(tagRepository: TagRepository(coreDataStack: CoreDataStack.shared))
            ),
            manageTagsUseCase: ManageTagsUseCase(tagRepository: TagRepository(coreDataStack: CoreDataStack.shared))
        )
    }
    
    
    
    var tagUseCase: ManageTagsUseCase {
        return manageTagsUseCase
    }
    
    
    
    func updateTags(_ tags: Set<Tag>) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // TODO: Record更新のUseCase実装が必要
            
            // 一時的にローカル更新
            var updatedRecord = record
            updatedRecord = Record(
                id: record.id,
                type: record.type,
                createdAt: record.createdAt,
                updatedAt: Date(),
                duration: record.duration,
                fileURL: record.fileURL,
                thumbnailURL: record.thumbnailURL,
                title: record.title,
                tags: tags,
                templateId: record.templateId
            )
            
            record = updatedRecord
            
        } catch {
            self.error = error
        }
    }
}