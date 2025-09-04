import Foundation
import Combine
import CoreData

// MARK: - Settings ViewModel
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isProVersion = false
    @Published var storageUsage: Int64 = 0
    @Published var totalStorage: Int64 = 0
    @Published var showingDeleteConfirmation = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    // MARK: - Properties
    private let subscriptionService: SubscriptionService
    private let cloudSyncService: CloudSyncService
    private let coreDataStack: CoreDataStack
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        subscriptionService: SubscriptionService,
        cloudSyncService: CloudSyncService,
        coreDataStack: CoreDataStack
    ) {
        self.subscriptionService = subscriptionService
        self.cloudSyncService = cloudSyncService
        self.coreDataStack = coreDataStack
        
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    func refreshData() {
        Task {
            await loadDataAsync()
        }
    }
    
    func purchaseProVersion() async throws {
        isProcessing = true
        defer { isProcessing = false }
        
        // 簡易実装：実際のサブスクリプション処理は後で実装
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒待機
        isProVersion = true
    }
    
    func restorePurchases() async {
        isProcessing = true
        defer { isProcessing = false }
        
        await subscriptionService.restorePurchases()
        await loadSubscriptionStatus()
    }
    
    func clearCache() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            // キャッシュクリア処理
            let cacheSize = try await clearCacheData()
            await loadStorageData()
            
            // 成功メッセージ（簡単な実装）
            print("Cache cleared: \(cacheSize) bytes")
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func deleteAllData() async {
        guard showingDeleteConfirmation else { return }
        
        isProcessing = true
        defer {
            isProcessing = false
            showingDeleteConfirmation = false
        }
        
        do {
            // 全データ削除処理
            try await deleteAllRecords()
            await loadStorageData()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // サブスクリプション状態の監視
        subscriptionService.$isProVersion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProVersion in
                self?.isProVersion = isProVersion
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadDataAsync()
        }
    }
    
    private func loadDataAsync() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadSubscriptionStatus()
            }
            
            group.addTask {
                await self.loadStorageData()
            }
        }
    }
    
    private func loadSubscriptionStatus() async {
        isProVersion = subscriptionService.isProVersion
    }
    
    private func loadStorageData() async {
        do {
            storageUsage = coreDataStack.getTotalStorageUsed()
            
            // 総容量の取得（簡易実装）
            if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
               let totalSpace = systemAttributes[.systemSize] as? Int64 {
                totalStorage = totalSpace
            } else {
                totalStorage = 128_000_000_000 // デフォルト128GB
            }
        }
    }
    
    private func clearCacheData() async throws -> Int64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var clearedSize: Int64 = 0
                let fileManager = FileManager.default
                
                if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator {
                        if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            clearedSize += Int64(fileSize)
                        }
                        try? fileManager.removeItem(at: fileURL)
                    }
                }
                
                continuation.resume(returning: clearedSize)
            }
        }
    }
    
    private func deleteAllRecords() async throws {
        // 全記録の削除（Core Dataから）
        let context = coreDataStack.viewContext
        
        let recordRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RecordEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: recordRequest)
        
        try context.execute(deleteRequest)
        try context.save()
        
        // ファイルシステムからも削除
        let recordsDirectory = Constants.Storage.recordsDirectory
        let thumbnailsDirectory = Constants.Storage.thumbnailsDirectory
        
        try? FileManager.default.removeItem(at: recordsDirectory)
        try? FileManager.default.removeItem(at: thumbnailsDirectory)
        
        // ディレクトリを再作成
        try FileManager.default.createDirectory(at: recordsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
        showingError = false
    }
    
    // MARK: - Computed Properties
    
    var storageUsagePercentage: Double {
        guard totalStorage > 0 else { return 0.0 }
        return Double(storageUsage) / Double(totalStorage)
    }
    
    var formattedStorageUsage: String {
        return ByteCountFormatter.string(fromByteCount: storageUsage, countStyle: .file)
    }
    
    var formattedTotalStorage: String {
        return ByteCountFormatter.string(fromByteCount: totalStorage, countStyle: .file)
    }
    
    var appVersion: String {
        return Constants.App.version
    }
    
    var buildNumber: String {
        return Constants.App.build
    }
}

// MARK: - Storage Info Extension
extension SettingsViewModel {
    var storageStatusText: String {
        if isProVersion {
            return "\(formattedStorageUsage) 使用中"
        } else {
            let limit = Constants.Storage.freeVersionStorageLimit()
            let limitFormatted = ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)
            return "\(formattedStorageUsage) / \(limitFormatted) 使用中"
        }
    }
    
    var isStorageWarning: Bool {
        if isProVersion { return false }
        
        let limit = Constants.Storage.freeVersionStorageLimit()
        return storageUsage > limit * 4 / 5 // 80%以上で警告
    }
}