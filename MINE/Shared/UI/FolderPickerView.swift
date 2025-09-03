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
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        List {
            Text("タグ編集画面（実装予定）")
                .foregroundColor(Theme.gray5)
                .padding()
        }
        .navigationTitle("タグ編集")
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