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
        if KeychainService.shared.isProVersion {
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
        
        if KeychainService.shared.isProVersion {
            try await cloudDataSource.updateRecord(record)
        }
    }
    
    func delete(_ id: UUID) async throws {
        try await localDataSource.deleteRecord(by: id)
        
        if KeychainService.shared.isProVersion {
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
        let _ = record.toEntity(context: context)
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
        
        
        // タグフィルタリング
        if let tags = filter.tags, !tags.isEmpty {
            let tagIds = tags.map { $0.id }
            predicates.append(NSPredicate(format: "ANY tags.id IN %@", tagIds))
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
            entity.comment = record.title
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

// MARK: - Folder Repository
class FolderRepository {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - CRUD Operations
    
    func save(_ folder: Folder) async throws {
        let context = coreDataStack.viewContext
        let entity = folder.toEntity(context: context)
        
        // 親フォルダの関係設定
        if let parentId = folder.parentFolderId {
            let parentRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
            parentRequest.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
            if let parentEntity = try context.fetch(parentRequest).first {
                entity.parentFolder = parentEntity
            }
        }
        
        coreDataStack.save()
    }
    
    func fetchAll() async throws -> [Folder] {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Folder(from: $0) }
    }
    
    func fetchById(_ id: UUID) async throws -> Folder? {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.first.flatMap { Folder(from: $0) }
    }
    
    func fetchByParentId(_ parentId: UUID?) async throws -> [Folder] {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        
        if let parentId = parentId {
            request.predicate = NSPredicate(format: "parentFolder.id == %@", parentId as CVarArg)
        } else {
            // ルートフォルダ（親がない）を取得
            request.predicate = NSPredicate(format: "parentFolder == nil")
        }
        
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Folder(from: $0) }
    }
    
    func update(_ folder: Folder) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", folder.id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        entity.name = folder.name
        entity.color = folder.color
        
        // 親フォルダの関係更新
        if let parentId = folder.parentFolderId {
            let parentRequest: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
            parentRequest.predicate = NSPredicate(format: "id == %@", parentId as CVarArg)
            entity.parentFolder = try context.fetch(parentRequest).first
        } else {
            entity.parentFolder = nil
        }
        
        coreDataStack.save()
    }
    
    func delete(_ id: UUID) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        // サブフォルダがある場合はエラー
        if let subFolders = entity.subFolders, subFolders.count > 0 {
            throw RepositoryError.hasSubfolders
        }
        
        // 記録がある場合はエラー
        if let records = entity.records, records.count > 0 {
            throw RepositoryError.hasRecords
        }
        
        context.delete(entity)
        coreDataStack.save()
    }
    
    func searchByName(_ searchText: String) async throws -> [Folder] {
        let request: NSFetchRequest<FolderEntity> = FolderEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Folder(from: $0) }
    }
    
    // フォルダ階層の取得（親から子への階層構造）
    func getFolderHierarchy() async throws -> [FolderHierarchy] {
        let allFolders = try await fetchAll()
        let rootFolders = allFolders.filter { $0.parentFolderId == nil }
        
        return rootFolders.map { rootFolder in
            buildHierarchy(folder: rootFolder, allFolders: allFolders)
        }
    }
    
    private func buildHierarchy(folder: Folder, allFolders: [Folder]) -> FolderHierarchy {
        let subFolders = allFolders.filter { $0.parentFolderId == folder.id }
        let children = subFolders.map { buildHierarchy(folder: $0, allFolders: allFolders) }
        
        return FolderHierarchy(folder: folder, children: children)
    }
}

// MARK: - Folder Hierarchy Model
struct FolderHierarchy {
    let folder: Folder
    let children: [FolderHierarchy]
    
    var totalRecordCount: Int {
        let directCount = folder.recordIds.count
        let childrenCount = children.reduce(0) { $0 + $1.totalRecordCount }
        return directCount + childrenCount
    }
}

class TagRepository {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - CRUD Operations
    
    func save(_ tag: Tag) async throws {
        let context = coreDataStack.viewContext
        let _ = tag.toEntity(context: context)
        coreDataStack.save()
    }
    
    func fetchAll() async throws -> [Tag] {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Tag(from: $0) }
    }
    
    func fetchById(_ id: UUID) async throws -> Tag? {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.first.flatMap { Tag(from: $0) }
    }
    
    func fetchByIds(_ ids: Set<UUID>) async throws -> [Tag] {
        guard !ids.isEmpty else { return [] }
        
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        let idArray = Array(ids)
        request.predicate = NSPredicate(format: "id IN %@", idArray)
        
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Tag(from: $0) }
    }
    
    func fetchPopularTags(limit: Int = 10) async throws -> [Tag] {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "usageCount > 0")
        
        let sortDescriptor = NSSortDescriptor(key: "usageCount", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        request.fetchLimit = limit
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Tag(from: $0) }
    }
    
    
    func update(_ tag: Tag) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        entity.name = tag.name
        entity.color = tag.color
        entity.usageCount = Int32(tag.usageCount)
        
        coreDataStack.save()
    }
    
    func delete(_ id: UUID) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        // タグが使用されている場合はエラー（使用数が0より大きい）
        if entity.usageCount > 0 {
            throw RepositoryError.tagInUse
        }
        
        context.delete(entity)
        coreDataStack.save()
    }
    
    func searchByName(_ searchText: String) async throws -> [Tag] {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { Tag(from: $0) }
    }
    
    func incrementUsage(_ id: UUID) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        entity.usageCount += 1
        coreDataStack.save()
    }
    
    func decrementUsage(_ id: UUID) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        if entity.usageCount > 0 {
            entity.usageCount -= 1
        }
        
        coreDataStack.save()
    }
    
    // タグの使用統計取得
    func getTagStatistics() async throws -> TagStatistics {
        let request: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        let entities = try coreDataStack.viewContext.fetch(request)
        
        let totalTags = entities.count
        let usedTags = entities.filter { $0.usageCount > 0 }.count
        let totalUsage = entities.reduce(0) { $0 + Int($1.usageCount) }
        let averageUsage = totalUsage > 0 ? Double(totalUsage) / Double(usedTags > 0 ? usedTags : 1) : 0.0
        
        return TagStatistics(
            totalTags: totalTags,
            usedTags: usedTags,
            totalUsage: totalUsage,
            averageUsage: averageUsage
        )
    }
}

// MARK: - Tag Statistics Model
struct TagStatistics {
    let totalTags: Int
    let usedTags: Int
    let totalUsage: Int
    let averageUsage: Double
}

class TemplateRepository {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - CRUD Operations
    
    func save(_ template: RecordTemplate) async throws {
        let context = coreDataStack.viewContext
        let _ = template.toEntity(context: context)
        coreDataStack.save()
    }
    
    func fetchAll() async throws -> [RecordTemplate] {
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "lastUsedAt", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { RecordTemplate(from: $0) }
    }
    
    func fetchById(_ id: UUID) async throws -> RecordTemplate? {
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.first.flatMap { RecordTemplate(from: $0) }
    }
    
    func fetchByRecordType(_ recordType: RecordType) async throws -> [RecordTemplate] {
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "recordType == %@", recordType.rawValue)
        
        let sortDescriptor = NSSortDescriptor(key: "usageCount", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { RecordTemplate(from: $0) }
    }
    
    func fetchRecentlyUsed(limit: Int = 10) async throws -> [RecordTemplate] {
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "lastUsedAt != nil")
        
        let sortDescriptor = NSSortDescriptor(key: "lastUsedAt", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        request.fetchLimit = limit
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { RecordTemplate(from: $0) }
    }
    
    func fetchMostUsed(limit: Int = 10) async throws -> [RecordTemplate] {
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "usageCount > 0")
        
        let sortDescriptor = NSSortDescriptor(key: "usageCount", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        request.fetchLimit = limit
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { RecordTemplate(from: $0) }
    }
    
    func update(_ template: RecordTemplate) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", template.id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        entity.name = template.name
        entity.recordType = template.recordType.rawValue
        entity.duration = template.duration ?? 0
        entity.usageCount = Int32(template.usageCount)
        entity.lastUsedAt = template.lastUsedAt
        entity.folderId = template.folderId
        
        // CropRect の更新
        if let cropRect = template.cropRect {
            entity.cropX = cropRect.origin.x
            entity.cropY = cropRect.origin.y
            entity.cropWidth = cropRect.width
            entity.cropHeight = cropRect.height
        } else {
            entity.cropX = 0
            entity.cropY = 0
            entity.cropWidth = 0
            entity.cropHeight = 0
        }
        
        // TagIDs をJSON文字列として保存
        if let tagIdsData = try? JSONEncoder().encode(template.tagIds),
           let tagIdsString = String(data: tagIdsData, encoding: .utf8) {
            entity.tagIds = tagIdsString
        }
        
        coreDataStack.save()
    }
    
    func delete(_ id: UUID) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        context.delete(entity)
        coreDataStack.save()
    }
    
    func searchByName(_ searchText: String) async throws -> [RecordTemplate] {
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", searchText)
        
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        let entities = try coreDataStack.viewContext.fetch(request)
        return entities.compactMap { RecordTemplate(from: $0) }
    }
    
    func incrementUsage(_ id: UUID) async throws {
        let context = coreDataStack.viewContext
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        guard let entity = try context.fetch(request).first else {
            throw RepositoryError.notFound
        }
        
        entity.usageCount += 1
        entity.lastUsedAt = Date()
        
        coreDataStack.save()
    }
    
    // テンプレートの使用統計取得
    func getTemplateStatistics() async throws -> TemplateStatistics {
        let request: NSFetchRequest<RecordTemplateEntity> = RecordTemplateEntity.fetchRequest()
        let entities = try coreDataStack.viewContext.fetch(request)
        
        let totalTemplates = entities.count
        let usedTemplates = entities.filter { $0.usageCount > 0 }.count
        let totalUsage = entities.reduce(0) { $0 + Int($1.usageCount) }
        let averageUsage = totalUsage > 0 ? Double(totalUsage) / Double(usedTemplates > 0 ? usedTemplates : 1) : 0.0
        
        // 記録タイプ別の統計
        let videoTemplates = entities.filter { $0.recordType == RecordType.video.rawValue }.count
        let audioTemplates = entities.filter { $0.recordType == RecordType.audio.rawValue }.count
        let imageTemplates = entities.filter { $0.recordType == RecordType.image.rawValue }.count
        
        return TemplateStatistics(
            totalTemplates: totalTemplates,
            usedTemplates: usedTemplates,
            totalUsage: totalUsage,
            averageUsage: averageUsage,
            videoTemplates: videoTemplates,
            audioTemplates: audioTemplates,
            imageTemplates: imageTemplates
        )
    }
}

// MARK: - Template Statistics Model
struct TemplateStatistics {
    let totalTemplates: Int
    let usedTemplates: Int
    let totalUsage: Int
    let averageUsage: Double
    let videoTemplates: Int
    let audioTemplates: Int
    let imageTemplates: Int
}

// MARK: - Repository Errors
enum RepositoryError: LocalizedError {
    case notFound
    case hasSubfolders
    case hasRecords
    case tagInUse
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "指定されたデータが見つかりません"
        case .hasSubfolders:
            return "サブフォルダが存在するため削除できません"
        case .hasRecords:
            return "記録が存在するため削除できません"
        case .tagInUse:
            return "使用中のタグは削除できません"
        case .invalidData:
            return "データが無効です"
        }
    }
}