import SwiftUI

// MARK: - Record Metadata Input View
struct RecordMetadataInputView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    
    let recordURL: URL
    let recordType: RecordType
    let onSave: (RecordMetadata) -> Void
    
    @State private var comment = ""
    @State private var selectedFolder: Folder?
    @State private var selectedTags: Set<Tag> = []
    @State private var newTagName = ""
    @State private var showingFolderCreation = false
    @State private var newFolderName = ""
    @State private var availableFolders: [Folder] = []
    @State private var availableTags: [Tag] = []
    @State private var isLoading = false
    @State private var showingVideoEditor = false
    @State private var showingImageEditor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        headerSection
                        
                        // プレビューセクション
                        previewSection
                        
                        // コメントセクション
                        commentSection
                        
                        // フォルダセクション
                        folderSection
                        
                        // タグセクション
                        tagSection
                    }
                    .padding()
                }
                
                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("記録を保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        // キャンセル時はデータを破棄
                        viewModel.discardRecording()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecord()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primary)
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadInitialData()
            }
            .sheet(isPresented: $showingVideoEditor) {
                VideoEditorView(videoURL: recordURL) { editedURL in
                    // 編集済みのURLで更新 
                    // 編集後は元のRecordMetadataInputViewに戻る
                }
            }
            .sheet(isPresented: $showingImageEditor) {
                ImageCropperView(imageURL: recordURL) { croppedURL in
                    // クロップ済みのURLで更新
                    // 編集後は元のRecordMetadataInputViewに戻る
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: recordType.systemImage)
                .font(.system(size: 48))
                .foregroundColor(Theme.primary)
            
            Text("\(recordType.displayName)を保存")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            Text("記録に詳細情報を追加しましょう")
                .font(.subheadline)
                .foregroundColor(Theme.gray5)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プレビュー")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            HStack(spacing: 12) {
                // プレビューサムネイル
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.gray1)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: recordType.systemImage)
                            .font(.title2)
                            .foregroundColor(Theme.gray4)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recordType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                    
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(Theme.gray5)
                    
                    // ファイルサイズ（概算）
                    Text("約 \(estimatedFileSize)")
                        .font(.caption)
                        .foregroundColor(Theme.gray4)
                }
                
                Spacer()
                
                // 編集ボタン
                if recordType == .video || recordType == .image {
                    VStack(spacing: 8) {
                        Button(action: {
                            if recordType == .video {
                                showingVideoEditor = true
                            } else if recordType == .image {
                                showingImageEditor = true
                            }
                        }) {
                            Image(systemName: recordType == .video ? "scissors" : "crop")
                                .font(.title3)
                                .foregroundColor(Theme.primary)
                        }
                        
                        Text(recordType == .video ? "編集" : "クロップ")
                            .font(.caption2)
                            .foregroundColor(Theme.primary)
                    }
                }
            }
            .padding()
            .background(Theme.gray1.opacity(0.5))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Comment Section
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("コメント")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("この記録について説明を追加...", text: $comment, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .lineLimit(3, reservesSpace: true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.gray1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.gray3, lineWidth: 1)
                            )
                    )
                
                Text("\(comment.count)/500")
                    .font(.caption2)
                    .foregroundColor(comment.count > 450 ? Theme.error : Theme.gray4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Folder Section
    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("フォルダ")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Button(action: { showingFolderCreation = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                        Text("新規作成")
                            .font(.caption)
                    }
                    .foregroundColor(Theme.primary)
                }
            }
            
            if availableFolders.isEmpty {
                emptyFolderState
            } else {
                folderSelectionGrid
            }
        }
    }
    
    private var emptyFolderState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.title)
                .foregroundColor(Theme.gray4)
            
            Text("フォルダがありません")
                .font(.subheadline)
                .foregroundColor(Theme.gray5)
            
            Button("最初のフォルダを作成") {
                showingFolderCreation = true
            }
            .font(.subheadline)
            .foregroundColor(Theme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.gray1.opacity(0.5))
        .cornerRadius(12)
    }
    
    private var folderSelectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            // 「なし」オプション
            FolderSelectionCard(
                folder: nil,
                isSelected: selectedFolder == nil,
                onTap: { selectedFolder = nil }
            )
            
            ForEach(availableFolders, id: \.id) { folder in
                FolderSelectionCard(
                    folder: folder,
                    isSelected: selectedFolder?.id == folder.id,
                    onTap: { selectedFolder = folder }
                )
            }
        }
    }
    
    // MARK: - Tag Section
    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("タグ")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Text("\(selectedTags.count) 個選択")
                    .font(.caption)
                    .foregroundColor(Theme.gray5)
            }
            
            // 新しいタグ作成
            newTagCreationField
            
            if availableTags.isEmpty {
                emptyTagState
            } else {
                tagSelectionArea
            }
        }
    }
    
    private var newTagCreationField: some View {
        HStack(spacing: 12) {
            TextField("新しいタグ名", text: $newTagName)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.gray1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.gray3, lineWidth: 1)
                        )
                )
            
            Button(action: createNewTag) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.gray3 : Theme.primary)
            }
            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    private var emptyTagState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag.circle")
                .font(.title)
                .foregroundColor(Theme.gray4)
            
            Text("タグがありません")
                .font(.subheadline)
                .foregroundColor(Theme.gray5)
            
            Text("上の入力欄で新しいタグを作成できます")
                .font(.caption)
                .foregroundColor(Theme.gray4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.gray1.opacity(0.5))
        .cornerRadius(12)
    }
    
    private var tagSelectionArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 選択されたタグ
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("選択中のタグ")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(Array(selectedTags), id: \.id) { tag in
                            SelectedTagChip(tag: tag) {
                                selectedTags.remove(tag)
                            }
                        }
                    }
                }
                
                Divider()
            }
            
            // 利用可能なタグ
            VStack(alignment: .leading, spacing: 8) {
                Text("利用可能なタグ")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.text)
                
                FlowLayout(spacing: 8) {
                    ForEach(availableTags.filter { !selectedTags.contains($0) }, id: \.id) { tag in
                        AvailableTagChip(tag: tag) {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.primary))
                    .scaleEffect(1.2)
                
                Text("保存中...")
                    .font(.subheadline)
                    .foregroundColor(Theme.text)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Theme.shadowColor, radius: 10)
        }
    }
    
    // MARK: - Computed Properties
    private var estimatedFileSize: String {
        switch recordType {
        case .video:
            return "15MB"
        case .audio:
            return "2MB"
        case .image:
            return "500KB"
        }
    }
    
    // MARK: - Actions
    private func loadInitialData() {
        Task {
            do {
                // フォルダとタグのデータを読み込み（実際のUseCaseを使用）
                // 現在は仮のデータを使用
                await MainActor.run {
                    self.availableFolders = Folder.defaultFolders
                    self.availableTags = [
                        Tag(id: UUID(), name: "筋トレ", color: "#F4A261", usageCount: 5),
                        Tag(id: UUID(), name: "カラオケ", color: "#67B3A3", usageCount: 3),
                        Tag(id: UUID(), name: "上達", color: "#4A90A4", usageCount: 8)
                    ]
                }
            }
        }
    }
    
    private func createNewTag() {
        let tagName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tagName.isEmpty else { return }
        
        // 既存のタグと重複チェック
        if availableTags.contains(where: { $0.name.lowercased() == tagName.lowercased() }) {
            return
        }
        
        let newTag = Tag(
            id: UUID(),
            name: tagName,
            color: Theme.primary.description,
            usageCount: 0
        )
        
        availableTags.append(newTag)
        selectedTags.insert(newTag)
        newTagName = ""
        
        // 触覚フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func saveRecord() {
        isLoading = true
        
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = RecordMetadata(
            comment: trimmedComment.isEmpty ? nil : trimmedComment,
            tags: Array(selectedTags), // SetをArrayに変換
            folderId: selectedFolder?.id // FolderのIDを取得
        )
        
        // 少し遅延を追加してリアルな保存感を演出
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            onSave(metadata)
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct FolderSelectionCard: View {
    let folder: Folder?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: folder == nil ? "tray" : "folder.fill")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : (folder == nil ? Theme.gray4 : Color(hex: folder!.color)))
                
                Text(folder?.name ?? "なし")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.primary : Theme.gray1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Theme.primary : Theme.gray3, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedTagChip: View {
    let tag: Tag
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag.name)
                .font(.caption)
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: tag.color))
        .cornerRadius(12)
    }
}

struct AvailableTagChip: View {
    let tag: Tag
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 6) {
                Text(tag.name)
                    .font(.caption)
                
                Image(systemName: "plus")
                    .font(.system(size: 10))
            }
            .foregroundColor(Color(hex: tag.color))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: tag.color).opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: tag.color), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var height: CGFloat = 0
        var maxRowHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + subviewSize.width + spacing > containerWidth && currentRowWidth > 0 {
                height += maxRowHeight + spacing
                currentRowWidth = subviewSize.width
                maxRowHeight = subviewSize.height
            } else {
                if currentRowWidth > 0 {
                    currentRowWidth += spacing
                }
                currentRowWidth += subviewSize.width
                maxRowHeight = max(maxRowHeight, subviewSize.height)
            }
        }
        
        height += maxRowHeight
        return CGSize(width: containerWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxRowHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentX + subviewSize.width > bounds.maxX && currentX > bounds.minX {
                currentY += maxRowHeight + spacing
                currentX = bounds.minX
                maxRowHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += subviewSize.width + spacing
            maxRowHeight = max(maxRowHeight, subviewSize.height)
        }
    }
}

// MARK: - Record Metadata Model
struct RecordMetadata {
    let comment: String?
    let tags: [Tag]
    let folderId: UUID?
}