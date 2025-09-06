import SwiftUI

// MARK: - Record Metadata Input View
struct RecordMetadataInputView: View {
    @ObservedObject var viewModel: RecordingViewModel
    @Environment(\.dismiss) private var dismiss
    
    let recordURL: URL
    let recordType: RecordType
    let onSave: (RecordMetadata) -> Void
    
    @State private var title = ""
    @State private var selectedTag: Tag? = nil
    @State private var newTagName = ""
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
                        
                        // タイトルセクション
                        titleSection
                        
                        // フォルダ機能は削除済み
                        
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
                        // キャンセル時はデータを破棄して録画画面全体を閉じる
                        viewModel.discardRecording()
                        // 録画画面全体を閉じる
                        if let presentationMode = viewModel.presentationMode {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            dismiss()
                        }
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
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タイトル（任意）")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            VStack(alignment: .leading, spacing: 8) {
                TextField(todayDateString, text: $title, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .lineLimit(2, reservesSpace: true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.gray1)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.gray3, lineWidth: 1)
                            )
                    )
                
                HStack {
                    if title.isEmpty {
                        Text("空の場合は「\(todayDateString)」が設定されます")
                            .font(.caption2)
                            .foregroundColor(Theme.gray4)
                    }
                    
                    Spacer()
                    
                    Text("\(title.count)/100")
                        .font(.caption2)
                        .foregroundColor(title.count > 80 ? Theme.error : Theme.gray4)
                }
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
                
                Text(selectedTag != nil ? "1 個選択" : "未選択")
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
            if let selectedTag = selectedTag {
                VStack(alignment: .leading, spacing: 8) {
                    Text("選択中のタグ")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                    
                    SelectedTagChip(tag: selectedTag) {
                        self.selectedTag = nil
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
                    ForEach(availableTags.filter { $0.id != selectedTag?.id }, id: \.id) { tag in
                        AvailableTagChip(tag: tag) {
                            selectedTag = tag
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
    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: Date())
    }
    
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
                // タグのデータを読み込み（実際のUseCaseを使用）
                // 現在は仮のデータを使用
                await MainActor.run {
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
        selectedTag = newTag
        newTagName = ""
        
        // 触覚フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func saveRecord() {
        isLoading = true
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty ? todayDateString : trimmedTitle
        let metadata = RecordMetadata(
            title: finalTitle,
            tags: selectedTag != nil ? [selectedTag!] : [] // 単一タグまたは空配列
        )
        
        // ViewModelで実際の保存処理を開始
        onSave(metadata)
        
        // ViewModelの保存完了を監視
        Task {
            // ViewModelのsavedCompletedがtrueになるまで待機
            while !viewModel.savedCompleted && viewModel.errorMessage == nil {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒ごとにチェック
            }
            
            await MainActor.run {
                isLoading = false
                // 保存完了時は画面を閉じる（RecordingViewがホームタブに遷移処理を行う）
                if viewModel.savedCompleted {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Supporting Views


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
    let title: String
    let tags: [Tag]
}