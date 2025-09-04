import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        List {
                // アプリ情報セクション
                Section {
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(Theme.primary)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("MINE")
                                .font(.headline)
                                .foregroundColor(Theme.text)
                            
                            Text("バージョン \(Constants.App.version)")
                                .font(.caption)
                                .foregroundColor(Theme.gray5)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // サブスクリプションセクション
                Section("サブスクリプション") {
                    Button {
                        appCoordinator.showSubscription()
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(Theme.accent)
                            
                            Text("MINE Pro")
                                .foregroundColor(Theme.text)
                            
                            Spacer()
                            
                            if viewModel.isProVersion {
                                Text("有効")
                                    .font(.caption)
                                    .foregroundColor(Theme.success)
                            } else {
                                Text("アップグレード")
                                    .font(.caption)
                                    .foregroundColor(Theme.primary)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.gray4)
                        }
                    }
                }
                
                // データ管理セクション
                Section("データ管理") {
                    Button {
                        // データバックアップ機能（実装予定）
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(Theme.primary)
                            
                            Text("データをバックアップ")
                                .foregroundColor(Theme.text)
                            
                            Spacer()
                            
                            if viewModel.isProVersion {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(Theme.gray4)
                            } else {
                                Text("Pro")
                                    .font(.caption)
                                    .foregroundColor(Theme.accent)
                            }
                        }
                    }
                    .disabled(!viewModel.isProVersion)
                    
                    Button {
                        // ストレージ管理機能（実装予定）
                    } label: {
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundColor(Theme.primary)
                            
                            VStack(alignment: .leading) {
                                Text("ストレージ")
                                    .foregroundColor(Theme.text)
                                
                                Text(viewModel.storageUsageText)
                                    .font(.caption)
                                    .foregroundColor(Theme.gray5)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.gray4)
                        }
                    }
                }
                
                // ヘルプセクション
                Section("ヘルプ") {
                    if let supportURL = URL(string: "https://example.com/support") {
                        Link(destination: supportURL) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(Theme.primary)
                                
                                Text("サポート")
                                    .foregroundColor(Theme.text)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(Theme.gray4)
                            }
                        }
                    }
                    
                    if let privacyURL = URL(string: "https://example.com/privacy") {
                        Link(destination: privacyURL) {
                            HStack {
                                Image(systemName: "hand.raised")
                                    .foregroundColor(Theme.primary)
                                
                                Text("プライバシーポリシー")
                                    .foregroundColor(Theme.text)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(Theme.gray4)
                            }
                        }
                    }
                    
                    if let termsURL = URL(string: "https://example.com/terms") {
                        Link(destination: termsURL) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(Theme.primary)
                                
                                Text("利用規約")
                                    .foregroundColor(Theme.text)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(Theme.gray4)
                            }
                        }
                    }
                }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

// Placeholder ViewModel
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isProVersion = false
    @Published var storageUsageText = "計算中..."
    
    private let subscriptionService: SubscriptionService
    private let cloudSyncService: CloudSyncService
    private let coreDataStack: CoreDataStack
    
    init(
        subscriptionService: SubscriptionService,
        cloudSyncService: CloudSyncService,
        coreDataStack: CoreDataStack
    ) {
        self.subscriptionService = subscriptionService
        self.cloudSyncService = cloudSyncService
        self.coreDataStack = coreDataStack
    }
    
    func loadSettings() {
        isProVersion = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion)
        
        // ストレージ使用量を計算
        Task {
            let usage = await calculateStorageUsage()
            await MainActor.run {
                self.storageUsageText = usage
            }
        }
    }
    
    private func calculateStorageUsage() async -> String {
        let totalSize = coreDataStack.getTotalStorageUsed()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}