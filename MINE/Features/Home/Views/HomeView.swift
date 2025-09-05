import SwiftUI
import PhotosUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Constants.UI.padding) {
                // ヘッダーセクション
                headerSection
                
                // クイック記録ボタン
                quickRecordSection
                
                // 写真ライブラリから選択
                photoLibrarySection
                
                // 統計情報
                statsSection
            }
            .padding(Constants.UI.padding)
        }
        .navigationTitle("MINE")
        .navigationBarTitleDisplayMode(.large)
        .background(Theme.background)
        .refreshable {
            await viewModel.loadDataAsync()
        }
        .onAppear {
            viewModel.loadData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日も成長の記録を")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Text(todayDateString)
                    .font(.subheadline)
                    .foregroundColor(Theme.gray5)
            }
            
            Spacer()
            
            // プロフィール画像プレースホルダー
            Circle()
                .fill(Theme.primary)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                )
        }
    }
    
    // MARK: - Quick Record Section
    private var quickRecordSection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.smallPadding) {
            Text("クイック記録")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            HStack(spacing: Constants.UI.smallPadding) {
                ForEach(RecordType.allCases, id: \.rawValue) { type in
                    QuickRecordButton(
                        type: type,
                        action: {
                            appCoordinator.showRecording(type: type)
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(Constants.UI.cornerRadius)
        .shadow(
            color: Theme.shadowColor,
            radius: Constants.UI.shadowRadius,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - Photo Library Section
    private var photoLibrarySection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.smallPadding) {
            Text("写真フォルダから選択")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .any(of: [.images, .videos])
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundColor(Theme.primary)
                    
                    Text("ライブラリから選択")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.gray4)
                }
                .padding()
                .background(Theme.gray1)
                .cornerRadius(Constants.UI.cornerRadius)
            }
            .onChange(of: selectedPhotoItems) {
                handleSelectedPhotos(selectedPhotoItems)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(Constants.UI.cornerRadius)
        .shadow(
            color: Theme.shadowColor,
            radius: Constants.UI.shadowRadius,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.smallPadding) {
            Text("全期間の統計")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            HStack(spacing: Constants.UI.smallPadding) {
                StatCardView(
                    title: "総記録数",
                    value: "\(viewModel.overallStats.totalRecordCount)",
                    icon: "chart.bar.fill",
                    color: Theme.primary
                )
                
                StatCardView(
                    title: "月間記録数",
                    value: "\(viewModel.overallStats.monthlyRecordCount)",
                    icon: "calendar.badge.plus",
                    color: Theme.accent
                )
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(Constants.UI.cornerRadius)
        .shadow(
            color: Theme.shadowColor,
            radius: Constants.UI.shadowRadius,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - Photo Handling
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                do {
                    // 写真/動画を一時的にローカルに保存して記録として追加
                    if let data = try await item.loadTransferable(type: Data.self) {
                        await processPhotoData(data, item: item)
                    }
                } catch {
                    print("Failed to load photo: \(error)")
                }
            }
            
            // 選択をクリア
            await MainActor.run {
                selectedPhotoItems.removeAll()
            }
        }
    }
    
    @MainActor
    private func processPhotoData(_ data: Data, item: PhotosPickerItem) async {
        do {
            // PhotosPickerItemからメディアタイプを判定
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            
            print("Processing \(isVideo ? "video" : "photo") data of size: \(data.count) bytes")
            
            // ViewModelの記録作成メソッドを呼び出し
            try await viewModel.createRecordFromPhotoData(data, isVideo: isVideo)
            
            print("Successfully created record from \(isVideo ? "video" : "photo")")
            
        } catch {
            print("Failed to create record from photo: \(error)")
            // エラーハンドリング - 実際のアプリではユーザーにエラーメッセージを表示
        }
    }
    
    // MARK: - Computed Properties
    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: Date())
    }
}

// MARK: - Quick Record Button
struct QuickRecordButton: View {
    let type: RecordType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .font(.title2)
                    .foregroundColor(Theme.primary)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.UI.padding)
            .background(Theme.gray1)
            .cornerRadius(Constants.UI.smallCornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Card View
struct StatCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.text)
            }
            
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.gray5)
                
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.gray1)
        .cornerRadius(Constants.UI.smallCornerRadius)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: Constants.UI.smallPadding) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(Theme.gray4)
            
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(Theme.text)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(Theme.gray5)
                .multilineTextAlignment(.center)
        }
        .padding(Constants.UI.largePadding)
    }
}

// MARK: - Record Thumbnail View
struct RecordThumbnailView: View {
    let record: Record
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                // サムネイル
                RoundedRectangle(cornerRadius: Constants.UI.smallCornerRadius)
                    .fill(Theme.gray2)
                    .frame(height: 80)
                    .overlay(
                        Image(systemName: record.type.systemImage)
                            .font(.title)
                            .foregroundColor(Theme.gray4)
                    )
                
                // 記録情報
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.formattedDate)
                        .font(.caption2)
                        .foregroundColor(Theme.gray5)
                    
                    Text(record.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                    
                    if let duration = record.formattedDuration {
                        Text(duration)
                            .font(.caption2)
                            .foregroundColor(Theme.primary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}