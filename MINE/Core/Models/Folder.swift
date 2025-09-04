import Foundation
import CoreData
import SwiftUI

// MARK: - Folder Model
struct Folder: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let parentFolderId: UUID?
    let subFolderIds: Set<UUID>
    let recordIds: Set<UUID>
    let createdAt: Date
    let color: String
    
    init(
        id: UUID = UUID(),
        name: String,
        parentFolderId: UUID? = nil,
        subFolderIds: Set<UUID> = [],
        recordIds: Set<UUID> = [],
        createdAt: Date = Date(),
        color: String = "#4A90A4"
    ) {
        self.id = id
        self.name = name
        self.parentFolderId = parentFolderId
        self.subFolderIds = subFolderIds
        self.recordIds = recordIds
        self.createdAt = createdAt
        self.color = color
    }
    
    // SwiftUI Color取得
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    // フォルダパス生成（親フォルダがある場合）
    func getPath(allFolders: [Folder]) -> String {
        var path = name
        var currentFolder = self
        
        while let parentId = currentFolder.parentFolderId,
              let parent = allFolders.first(where: { $0.id == parentId }) {
            path = "\(parent.name) / \(path)"
            currentFolder = parent
        }
        
        return path
    }
    
    // 記録数（サブフォルダも含む）
    func getTotalRecordCount(allFolders: [Folder]) -> Int {
        var count = recordIds.count
        
        for subFolderId in subFolderIds {
            if let subFolder = allFolders.first(where: { $0.id == subFolderId }) {
                count += subFolder.getTotalRecordCount(allFolders: allFolders)
            }
        }
        
        return count
    }
}

// MARK: - Core Data Entity Extension
extension Folder {
    // Core Data Entityから変換
    init?(from entity: FolderEntity) {
        guard let id = entity.id,
              let name = entity.name,
              let createdAt = entity.createdAt,
              let color = entity.color else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.parentFolderId = entity.parentFolder?.id
        self.createdAt = createdAt
        self.color = color
        
        // サブフォルダIDs
        if let subFolders = entity.subFolders as? Set<FolderEntity> {
            self.subFolderIds = Set(subFolders.compactMap { $0.id })
        } else {
            self.subFolderIds = []
        }
        
        // レコードIDs
        if let records = entity.records as? Set<RecordEntity> {
            self.recordIds = Set(records.compactMap { $0.id })
        } else {
            self.recordIds = []
        }
    }
    
    // Core Data Entityへ変換
    func toEntity(context: NSManagedObjectContext) -> FolderEntity {
        let entity = FolderEntity(context: context)
        entity.id = id
        entity.name = name
        entity.createdAt = createdAt
        entity.color = color
        
        // 親フォルダとサブフォルダの関係は別途設定が必要
        
        return entity
    }
}

// MARK: - Default Folders
extension Folder {
    static let defaultFolders: [Folder] = [
        Folder(name: "筋トレ", color: "#F4A261"),
        Folder(name: "カラオケ", color: "#67B3A3"),
        Folder(name: "スポーツ", color: "#4A90A4")
    ]
}