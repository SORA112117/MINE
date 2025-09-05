import Foundation
import CoreData

// MARK: - RecordType
enum RecordType: String, CaseIterable, Codable {
    case video = "video"
    case audio = "audio"
    case image = "image"
    
    var displayName: String {
        switch self {
        case .video: return "動画"
        case .audio: return "音声"
        case .image: return "画像"
        }
    }
    
    var systemImage: String {
        switch self {
        case .video: return "video.fill"
        case .audio: return "mic.fill"
        case .image: return "photo.fill"
        }
    }
}

// MARK: - Record Model
struct Record: Identifiable, Codable {
    let id: UUID
    let type: RecordType
    let createdAt: Date
    let updatedAt: Date
    let duration: TimeInterval?
    let fileURL: URL
    let thumbnailURL: URL?
    let title: String
    let tags: Set<Tag>
    let templateId: UUID?
    
    init(
        id: UUID = UUID(),
        type: RecordType,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        duration: TimeInterval? = nil,
        fileURL: URL,
        thumbnailURL: URL? = nil,
        title: String,
        tags: Set<Tag> = [],
        templateId: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.duration = duration
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.title = title
        self.tags = tags
        self.templateId = templateId
    }
    
    // 表示用フォーマット
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: createdAt)
    }
}

// MARK: - Core Data Entity Extension
extension Record {
    // Core Data Entityから変換
    init?(from entity: RecordEntity) {
        guard let id = entity.id,
              let typeString = entity.type,
              let type = RecordType(rawValue: typeString),
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt,
              let fileURLString = entity.fileURL,
              let fileURL = URL(string: fileURLString) else {
            return nil
        }
        
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.duration = entity.duration
        self.fileURL = fileURL
        
        if let thumbnailURLString = entity.thumbnailURL {
            self.thumbnailURL = URL(string: thumbnailURLString)
        } else {
            self.thumbnailURL = nil
        }
        
        self.title = entity.comment ?? ""
        
        // タグの変換
        if let tagEntities = entity.tags as? Set<TagEntity> {
            self.tags = Set(tagEntities.compactMap { Tag(from: $0) })
        } else {
            self.tags = []
        }
        
        self.templateId = entity.templateId
    }
    
    // Core Data Entityへ変換
    func toEntity(context: NSManagedObjectContext) -> RecordEntity {
        let entity = RecordEntity(context: context)
        entity.id = id
        entity.type = type.rawValue
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.duration = duration ?? 0
        entity.fileURL = fileURL.absoluteString
        entity.thumbnailURL = thumbnailURL?.absoluteString
        entity.comment = title
        entity.templateId = templateId
        
        
        // タグの設定 - リレーションを使用
        if !tags.isEmpty {
            let tagEntities = tags.compactMap { tag -> TagEntity? in
                let tagRequest: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
                tagRequest.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)
                
                if let existingTag = try? context.fetch(tagRequest).first {
                    return existingTag
                } else {
                    // タグが存在しない場合は作成
                    let newTag = TagEntity(context: context)
                    newTag.id = tag.id
                    newTag.name = tag.name
                    newTag.color = tag.color
                    newTag.usageCount = Int32(tag.usageCount)
                    return newTag
                }
            }
            entity.tags = NSSet(array: tagEntities)
        }
        
        return entity
    }
}