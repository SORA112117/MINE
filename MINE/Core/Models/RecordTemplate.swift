import Foundation
import CoreData
import CoreGraphics

// MARK: - RecordTemplate Model
struct RecordTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let recordType: RecordType
    let duration: TimeInterval?
    let cropRect: CGRect?
    let tagIds: Set<UUID>
    let folderId: UUID?
    let createdAt: Date
    let lastUsedAt: Date?
    let usageCount: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        recordType: RecordType,
        duration: TimeInterval? = nil,
        cropRect: CGRect? = nil,
        tagIds: Set<UUID> = [],
        folderId: UUID? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.recordType = recordType
        self.duration = duration
        self.cropRect = cropRect
        self.tagIds = tagIds
        self.folderId = folderId
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
    
    // 表示用フォーマット
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration)
    }
    
    var formattedLastUsed: String? {
        guard let lastUsedAt = lastUsedAt else { return "未使用" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastUsedAt, relativeTo: Date())
    }
    
    // テンプレートから新規記録作成用の設定を取得
    func createRecordingSettings() -> RecordingSettings {
        RecordingSettings(
            type: recordType,
            duration: duration,
            cropRect: cropRect,
            tagIds: tagIds,
            folderId: folderId
        )
    }
}

// MARK: - RecordingSettings
struct RecordingSettings: Codable {
    let type: RecordType
    let duration: TimeInterval?
    let cropRect: CGRect?
    let tagIds: Set<UUID>
    let folderId: UUID?
    
    init(
        type: RecordType,
        duration: TimeInterval? = nil,
        cropRect: CGRect? = nil,
        tagIds: Set<UUID> = [],
        folderId: UUID? = nil
    ) {
        self.type = type
        self.duration = duration
        self.cropRect = cropRect
        self.tagIds = tagIds
        self.folderId = folderId
    }
}

// MARK: - Core Data Entity Extension
extension RecordTemplate {
    // Core Data Entityから変換
    init?(from entity: RecordTemplateEntity) {
        guard let id = entity.id,
              let name = entity.name,
              let typeString = entity.recordType,
              let type = RecordType(rawValue: typeString),
              let createdAt = entity.createdAt else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.recordType = type
        self.duration = entity.duration > 0 ? entity.duration : nil
        self.createdAt = createdAt
        self.lastUsedAt = entity.lastUsedAt
        self.usageCount = Int(entity.usageCount)
        
        // CropRect の変換
        if entity.cropX > 0 || entity.cropY > 0 || entity.cropWidth > 0 || entity.cropHeight > 0 {
            self.cropRect = CGRect(
                x: entity.cropX,
                y: entity.cropY,
                width: entity.cropWidth,
                height: entity.cropHeight
            )
        } else {
            self.cropRect = nil
        }
        
        // TagIDs の変換（JSON文字列として保存されていると仮定）
        if let tagIdsData = entity.tagIds?.data(using: .utf8),
           let tagIds = try? JSONDecoder().decode(Set<UUID>.self, from: tagIdsData) {
            self.tagIds = tagIds
        } else {
            self.tagIds = []
        }
        
        self.folderId = entity.folderId
    }
    
    // Core Data Entityへ変換
    func toEntity(context: NSManagedObjectContext) -> RecordTemplateEntity {
        let entity = RecordTemplateEntity(context: context)
        entity.id = id
        entity.name = name
        entity.recordType = recordType.rawValue
        entity.duration = duration ?? 0
        entity.createdAt = createdAt
        entity.lastUsedAt = lastUsedAt
        entity.usageCount = Int32(usageCount)
        entity.folderId = folderId
        
        // CropRect の保存
        if let cropRect = cropRect {
            entity.cropX = cropRect.origin.x
            entity.cropY = cropRect.origin.y
            entity.cropWidth = cropRect.width
            entity.cropHeight = cropRect.height
        }
        
        // TagIDs をJSON文字列として保存
        if let tagIdsData = try? JSONEncoder().encode(tagIds),
           let tagIdsString = String(data: tagIdsData, encoding: .utf8) {
            entity.tagIds = tagIdsString
        }
        
        return entity
    }
}

// MARK: - Default Templates
extension RecordTemplate {
    static let defaultTemplates: [RecordTemplate] = [
        RecordTemplate(
            name: "筋トレ記録",
            recordType: .video,
            duration: 5.0
        ),
        RecordTemplate(
            name: "カラオケ練習",
            recordType: .audio,
            duration: 90.0
        ),
        RecordTemplate(
            name: "フォーム確認",
            recordType: .video,
            duration: 3.0
        )
    ]
}