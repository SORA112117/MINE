import SwiftUI

// MARK: - Timeline Record Card
struct TimelineRecordCard: View {
    let record: Record
    let comparisonMode: ComparisonMode
    let isBackground: Bool
    let onTap: () -> Void
    
    @State private var imageLoadState: ImageLoadState = .loading
    @State private var thumbnailImage: UIImage?
    
    init(
        record: Record,
        comparisonMode: ComparisonMode,
        isBackground: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.record = record
        self.comparisonMode = comparisonMode
        self.isBackground = isBackground
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // サムネイルエリア
                thumbnailArea
                
                // 情報エリア
                informationArea
            }
            .background(Color.white)
            .cornerRadius(Constants.UI.cornerRadius)
            .shadow(
                color: isBackground ? Color.clear : Theme.shadowColor,
                radius: isBackground ? 0 : 3,
                x: 0,
                y: 2
            )
            .overlay(
                // 比較モード用のボーダー
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(
                        comparisonMode == .overlay && isBackground ? 
                        Theme.primary.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isBackground ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isBackground)
        .onAppear {
            loadThumbnail()
        }
    }
    
    // MARK: - Thumbnail Area
    private var thumbnailArea: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Rectangle()
                    .fill(Theme.gray1)
                    .frame(height: 180)
                
                // サムネイル画像
                switch imageLoadState {
                case .loading:
                    loadingPlaceholder
                case .loaded:
                    if let thumbnailImage = thumbnailImage {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } else {
                        fallbackPlaceholder
                    }
                case .failed:
                    fallbackPlaceholder
                }
                
                // オーバーレイ情報
                overlayInformation
            }
        }
        .frame(height: 180)
        .cornerRadius(Constants.UI.cornerRadius, corners: [.topLeft, .topRight])
    }
    
    // MARK: - Loading Placeholder
    private var loadingPlaceholder: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.gray4))
                .scaleEffect(0.8)
            
            Text("読み込み中...")
                .font(.caption2)
                .foregroundColor(Theme.gray4)
        }
    }
    
    // MARK: - Fallback Placeholder
    private var fallbackPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: record.type.systemImage)
                .font(.system(size: 32))
                .foregroundColor(Theme.gray4)
            
            Text(record.type.displayName)
                .font(.caption)
                .foregroundColor(Theme.gray4)
        }
    }
    
    // MARK: - Overlay Information
    private var overlayInformation: some View {
        VStack {
            // 上部：記録タイプバッジ
            HStack {
                recordTypeBadge
                Spacer()
                
                // 比較モード表示
                if comparisonMode == .overlay {
                    comparisonBadge
                }
            }
            .padding(8)
            
            Spacer()
            
            // 下部：時間情報
            HStack {
                Spacer()
                
                if let duration = record.formattedDuration {
                    durationBadge(duration)
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - Record Type Badge
    private var recordTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: record.type.systemImage)
                .font(.caption2)
            Text(record.type.displayName)
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
        )
    }
    
    // MARK: - Comparison Badge
    private var comparisonBadge: some View {
        Text(isBackground ? "比較対象" : "最新")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isBackground ? Theme.secondary.opacity(0.9) : Theme.primary.opacity(0.9))
            )
    }
    
    // MARK: - Duration Badge
    private func durationBadge(_ duration: String) -> some View {
        Text(duration)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.7))
            )
    }
    
    // MARK: - Information Area
    private var informationArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // タイトル行
            titleRow
            
            // メタデータ行
            metadataRow
            
            // タグエリア
            if !record.tags.isEmpty {
                tagArea
            }
            
            // 成長指標（将来の機能）
            if comparisonMode != .sideBySide {
                progressIndicator
            }
        }
        .padding(12)
    }
    
    // MARK: - Title Row
    private var titleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.formattedDate)
                    .font(.caption2)
                    .foregroundColor(Theme.gray5)
                
                if let comment = record.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                } else {
                    Text("記録 #\(record.id.uuidString.prefix(8))")
                        .font(.subheadline)
                        .foregroundColor(Theme.gray4)
                }
            }
            
            Spacer()
            
            // フォルダ表示
            // フォルダ表示は今後実装予定
            // if let folder = record.folder {
            //     folderBadge(folder)
            // }
        }
    }
    
    // MARK: - Metadata Row
    private var metadataRow: some View {
        HStack(spacing: 8) {
            // 作成時刻
            Text(formattedTime)
                .font(.caption2)
                .foregroundColor(Theme.gray4)
            
            // セパレーター
            Circle()
                .fill(Theme.gray3)
                .frame(width: 2, height: 2)
            
            // ファイルサイズ（概算）
            Text(estimatedFileSize)
                .font(.caption2)
                .foregroundColor(Theme.gray4)
            
            Spacer()
            
            // 比較表示フラグ
            if comparisonMode == .overlay && !isBackground {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption2)
                    .foregroundColor(Theme.primary)
            }
        }
    }
    
    // MARK: - Tag Area
    private var tagArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(record.tags.prefix(3)), id: \.id) { tag in
                    tagChip(tag)
                }
                
                if record.tags.count > 3 {
                    Text("+\(record.tags.count - 3)")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.gray4)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Theme.gray2)
                        )
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption2)
                .foregroundColor(Theme.primary.opacity(0.7))
            
            Text("成長指標は今後実装予定")
                .font(.caption2)
                .foregroundColor(Theme.gray4)
                .italic()
            
            Spacer()
        }
    }
    
    // MARK: - Helper Views
    // フォルダバッジは今後実装予定
    /*
    private func folderBadge(_ folder: Folder) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "folder.fill")
                .font(.system(size: 8))
            Text(folder.name)
                .font(.system(size: 9))
        }
        .foregroundColor(Color(hex: folder.color))
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(hex: folder.color).opacity(0.1))
        )
    }
    */
    
    private func tagChip(_ tag: Tag) -> some View {
        Text(tag.name)
            .font(.system(size: 9))
            .foregroundColor(Color(hex: tag.color))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(hex: tag.color).opacity(0.1))
            )
    }
    
    // MARK: - Computed Properties
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: record.createdAt)
    }
    
    private var estimatedFileSize: String {
        // ファイルサイズの概算計算（実装は後で詳細化）
        switch record.type {
        case .video:
            return "~15MB"
        case .audio:
            return "~2MB"
        case .image:
            return "~500KB"
        }
    }
    
    // MARK: - Actions
    private func loadThumbnail() {
        Task {
            do {
                if let thumbnailURL = record.thumbnailURL,
                   let imageData = try? Data(contentsOf: thumbnailURL),
                   let image = UIImage(data: imageData) {
                    await MainActor.run {
                        self.thumbnailImage = image
                        self.imageLoadState = .loaded
                    }
                } else {
                    await MainActor.run {
                        self.imageLoadState = .failed
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types
enum ImageLoadState {
    case loading
    case loaded
    case failed
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}