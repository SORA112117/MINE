import Foundation
import CoreData

// MARK: - Record Repository
class RecordRepository {
    private let localDataSource: LocalDataSource
    private let cloudDataSource: CloudDataSource
    
    init(localDataSource: LocalDataSource, cloudDataSource: CloudDataSource) {
        self.localDataSource = localDataSource
        self.cloudDataSource = cloudDataSource
    }
    
    // MARK: - CRUD Operations
    
    func save(_ record: Record) async throws {
        try await localDataSource.saveRecord(record)
        
        // Pro版の場合はクラウド同期も実行
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion) {
            try await cloudDataSource.uploadRecord(record)
        }
    }
    
    func fetch(with filter: RecordFilter) async throws -> [Record] {
        return try await localDataSource.fetchRecords(with: filter)
    }
    
    func fetchById(_ id: UUID) async throws -> Record? {
        return try await localDataSource.fetchRecord(by: id)
    }
    
    func update(_ record: Record) async throws {
        try await localDataSource.updateRecord(record)
        
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion) {
            try await cloudDataSource.updateRecord(record)
        }
    }
    
    func delete(_ id: UUID) async throws {
        try await localDataSource.deleteRecord(by: id)
        
        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.isProVersion) {
            try await cloudDataSource.deleteRecord(by: id)
        }
    }
    
    func deleteAll() async throws {
        try await localDataSource.deleteAllRecords()
    }
}

// MARK: - Local Data Source
class LocalDataSource {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    func saveRecord(_ record: Record) async throws {
        let context = coreDataStack.viewContext
        let entity = record.toEntity(context: context)
        coreDataStack.save()
    }
    
    func fetchRecords(with filter: RecordFilter) async throws -> [Record] {
        let request: NSFetchRequest<RecordEntity> = RecordEntity.fetchRequest()
        
        // Predicate
        var predicates: [NSPredicate] = []
        
        if let types = filter.types, !types.isEmpty {
            let typeStrings = types.map { $0.rawValue }
            predicates.append(NSPredicate(format: "type IN %@", typeStrings))
        }
        
        if let dateRange = filter.dateRange {
            predicates.append(NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", 
                                        dateRange.lowerBound as NSDate, 
                                        dateRange.upperBound as NSDate))
        }
        
        if let searchText = filter.searchText, !searchText.isEmpty {
            predicates.append(NSPredicate(format: "comment CONTAINS[cd] %@", searchText))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Sort
        let sortDescriptor: NSSortDescriptor
        switch filter.sortBy {
        case .createdAt:
            sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: filter.sortOrder == .ascending)
        case .updatedAt:
            sortDescriptor = NSSortDescriptor(key: "updatedAt", ascending: filter.sortOrder == .ascending)
        case .duration:
            sortDescriptor = NSSortDescriptor(key: "duration", ascending: filter.sortOrder == .ascending)
        case .name:
            sortDescriptor = NSSortDescriptor(key: "comment", ascending: filter.sortOrder == .ascending)
        }
        request.sortDescriptors = [sortDescriptor]
        
        // Limit & Offset
        if let limit = filter.limit {
            request.fetchLimit = limit
        }
        if let offset = filter.offset {
            request.fetchOffset = offset
        }
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Record(from: $0) }
    }
    
    func fetchRecord(by id: UUID) async throws -> Record? {
        let request: NSFetchRequest<RecordEntity> = RecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.first.flatMap { Record(from: $0) }
    }
    
    func updateRecord(_ record: Record) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<RecordEntity> = RecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
        
        let entities = try context.fetch(request)
        if let entity = entities.first {
            // 既存のエンティティを更新
            entity.updatedAt = Date()
            entity.comment = record.comment
            entity.duration = record.duration ?? 0
            // 他のプロパティも必要に応じて更新
            
            coreDataStack.save()
        }
    }
    
    func deleteRecord(by id: UUID) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<RecordEntity> = RecordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let entities = try context.fetch(request)
        entities.forEach { context.delete($0) }
        
        coreDataStack.save()
    }
    
    func deleteAllRecords() async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = RecordEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        try context.execute(deleteRequest)
        coreDataStack.save()
    }
}

// MARK: - Cloud Data Source
class CloudDataSource {
    
    func uploadRecord(_ record: Record) async throws {
        // CloudKit実装（プレースホルダー）
        print("Uploading record to cloud: \(record.id)")
    }
    
    func updateRecord(_ record: Record) async throws {
        // CloudKit実装（プレースホルダー）
        print("Updating record in cloud: \(record.id)")
    }
    
    func deleteRecord(by id: UUID) async throws {
        // CloudKit実装（プレースホルダー）
        print("Deleting record from cloud: \(id)")
    }
}

// MARK: - Other Repositories (Placeholder)
class FolderRepository {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
}

class TagRepository {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
}

class TemplateRepository {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
}