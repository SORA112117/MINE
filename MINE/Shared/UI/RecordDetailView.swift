import SwiftUI

struct RecordDetailView: View {
    let record: Record
    @EnvironmentObject var appCoordinator: AppCoordinator
    
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
                    
                    if let comment = record.comment, !comment.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("コメント:")
                                .foregroundColor(Theme.gray5)
                            
                            Text(comment)
                                .foregroundColor(Theme.text)
                                .padding()
                                .background(Theme.gray1)
                                .cornerRadius(Constants.UI.smallCornerRadius)
                        }
                    }
                    
                    // タグ表示
                    if !record.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タグ:")
                                .foregroundColor(Theme.gray5)
                            
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible()), count: 3),
                                spacing: 8
                            ) {
                                ForEach(Array(record.tags), id: \.id) { tag in
                                    HStack {
                                        Text(tag.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(tag.swiftUIColor)
                                            .cornerRadius(Constants.UI.smallCornerRadius)
                                    }
                                }
                            }
                        }
                    }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる") {
                    appCoordinator.dismissSheet()
                }
            }
        }
    }
}