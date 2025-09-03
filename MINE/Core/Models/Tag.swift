import Foundation
import CoreData
import SwiftUI

// MARK: - Tag Model
struct Tag: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let color: String
    let usageCount: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        color: String = "#4A90A4",
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.usageCount = usageCount
    }
    
    // SwiftUI Color取得
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Core Data Entity Extension
extension Tag {
    // Core Data Entityから変換
    init?(from entity: TagEntity) {
        guard let id = entity.id,
              let name = entity.name,
              let color = entity.color else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.color = color
        self.usageCount = Int(entity.usageCount)
    }
    
    // Core Data Entityへ変換
    func toEntity(context: NSManagedObjectContext) -> TagEntity {
        let entity = TagEntity(context: context)
        entity.id = id
        entity.name = name
        entity.color = color
        entity.usageCount = Int32(usageCount)
        
        return entity
    }
}

// MARK: - Default Tags
extension Tag {
    static let defaultTags: [Tag] = [
        Tag(name: "筋トレ", color: "#F4A261"),
        Tag(name: "カラオケ", color: "#67B3A3"),
        Tag(name: "スポーツ", color: "#4A90A4"),
        Tag(name: "練習", color: "#52C41A"),
        Tag(name: "本番", color: "#F5222D"),
        Tag(name: "お気に入り", color: "#FAAD14")
    ]
}