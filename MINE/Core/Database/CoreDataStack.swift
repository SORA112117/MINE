import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        // CloudKit統合は開発中のため、通常のCore Dataコンテナを使用
        let container = NSPersistentContainer(name: "MINEDataModel")
        
        // CloudKit統合は将来の実装のため、現在は無効
        // TODO: 本番環境でCloudKitを有効にする場合、適切なentitlementとprovisioning profileが必要
        /*
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion) {
            container.persistentStoreDescriptions.forEach { storeDescription in
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.mine.app"
                )
            }
        }
        */
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                // 開発中はfatalErrorではなく、エラーログのみ出力
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Core Data Operations
    
    func save() {
        let context = viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - Fetch Operations
    
    func fetch<T: NSManagedObject>(_ type: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [T] {
        let request = T.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        do {
            return try viewContext.fetch(request) as? [T] ?? []
        } catch {
            print("Fetch error: \(error)")
            return []
        }
    }
    
    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        save()
    }
    
    // MARK: - Storage Management
    
    func getTotalStorageUsed() -> Int64 {
        var totalSize: Int64 = 0
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            let enumerator = fileManager.enumerator(
                at: documentsURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )!
            
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            }
        } catch {
            print("Error calculating storage: \(error)")
        }
        
        return totalSize
    }
    
    func isStorageLimitReached() -> Bool {
        let isProVersion = KeychainService.shared.isProVersion
        
        if isProVersion {
            return false // 有料版は無制限
        }
        
        let currentUsage = getTotalStorageUsed()
        let limit = Constants.Storage.freeVersionStorageLimit()
        
        return currentUsage >= limit
    }
    
    // MARK: - Migration
    
    func performMigrationIfNeeded() {
        // バージョン管理と必要に応じたマイグレーション処理
        let currentVersion = UserDefaults.standard.integer(forKey: "CoreDataModelVersion")
        let latestVersion = 1
        
        if currentVersion < latestVersion {
            // マイグレーション処理
            UserDefaults.standard.set(latestVersion, forKey: "CoreDataModelVersion")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupOldData(olderThan days: Int) {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        
        performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<RecordEntity> = RecordEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
            
            do {
                let oldRecords = try context.fetch(fetchRequest)
                
                for record in oldRecords {
                    // ファイルも削除
                    if let fileURLString = record.fileURL,
                       let fileURL = URL(string: fileURLString) {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                    
                    if let thumbnailURLString = record.thumbnailURL,
                       let thumbnailURL = URL(string: thumbnailURLString) {
                        try? FileManager.default.removeItem(at: thumbnailURL)
                    }
                    
                    context.delete(record)
                }
                
                try context.save()
            } catch {
                print("Cleanup error: \(error)")
            }
        }
    }
}