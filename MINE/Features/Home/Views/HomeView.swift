import SwiftUI

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Constants.UI.padding) {
                // ヘッダーセクション
                headerSection
                
                // クイック記録ボタン
                quickRecordSection
                
                // 最近の記録
                recentRecordsSection
                
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
    
    // MARK: - Recent Records Section
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.smallPadding) {
            HStack {
                Text("最近の記録")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.text)
                
                Spacer()
                
                Button("すべて表示") {
                    appCoordinator.showRecords()
                }
                .font(.subheadline)
                .foregroundColor(Theme.primary)
            }
            
            if viewModel.recentRecords.isEmpty {
                EmptyStateView(
                    title: "まだ記録がありません",
                    message: "上のボタンから記録を始めましょう",
                    systemImage: "plus.circle"
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 2),
                    spacing: Constants.UI.smallPadding
                ) {
                    ForEach(viewModel.recentRecords.prefix(4), id: \.id) { record in
                        RecordThumbnailView(record: record) {
                            appCoordinator.showRecordDetail(record)
                        }
                    }
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
    
    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Constants.UI.smallPadding) {
            Text("今週の統計")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            
            HStack(spacing: Constants.UI.smallPadding) {
                StatCardView(
                    title: "記録回数",
                    value: "\(viewModel.weeklyStats.recordCount)",
                    icon: "chart.bar.fill",
                    color: Theme.primary
                )
                
                StatCardView(
                    title: "継続日数",
                    value: "\(viewModel.weeklyStats.streakDays)",
                    icon: "flame.fill",
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
                    
                    if let comment = record.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.text)
                            .lineLimit(2)
                    } else {
                        Text(record.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.text)
                    }
                    
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