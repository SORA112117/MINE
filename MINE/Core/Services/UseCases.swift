import Foundation

// MARK: - Use Cases

// MARK: - Create Record Use Case
class CreateRecordUseCase {
    private let recordRepository: RecordRepository
    private let mediaService: MediaService
    
    init(recordRepository: RecordRepository, mediaService: MediaService) {
        self.recordRepository = recordRepository
        self.mediaService = mediaService
    }
    
    func execute(
        type: RecordType,
        fileURL: URL,
        duration: TimeInterval? = nil,
        comment: String? = nil,
        tags: Set<Tag> = [],
        folderId: UUID? = nil
    ) async throws -> Record {
        
        // サムネイル生成
        let thumbnailURL = await mediaService.generateThumbnail(for: fileURL, recordType: type)
        
        // 記録作成
        let record = Record(
            type: type,
            createdAt: Date(),
            updatedAt: Date(),
            duration: duration,
            fileURL: fileURL,
            thumbnailURL: thumbnailURL,
            comment: comment,
            tags: tags,
            folderId: folderId,
            templateId: nil
        )
        
        // 保存
        try await recordRepository.save(record)
        
        return record
    }
}

// MARK: - Get Records Use Case
class GetRecordsUseCase {
    private let recordRepository: RecordRepository
    
    init(recordRepository: RecordRepository) {
        self.recordRepository = recordRepository
    }
    
    func execute(filter: RecordFilter = RecordFilter()) async throws -> [Record] {
        return try await recordRepository.fetch(with: filter)
    }
    
    func execute(by id: UUID) async throws -> Record? {
        return try await recordRepository.fetchById(id)
    }
}

// MARK: - Delete Record Use Case
class DeleteRecordUseCase {
    private let recordRepository: RecordRepository
    private let mediaService: MediaService
    
    init(recordRepository: RecordRepository, mediaService: MediaService) {
        self.recordRepository = recordRepository
        self.mediaService = mediaService
    }
    
    func execute(id: UUID) async throws {
        // まず記録を取得
        guard let record = try await recordRepository.fetchById(id) else {
            throw UseCaseError.recordNotFound
        }
        
        // 関連ファイルを削除
        try await mediaService.deleteFile(at: record.fileURL)
        
        if let thumbnailURL = record.thumbnailURL {
            try await mediaService.deleteFile(at: thumbnailURL)
        }
        
        // データベースから削除
        try await recordRepository.delete(id)
    }
}

// MARK: - Manage Folders Use Case
class ManageFoldersUseCase {
    private let folderRepository: FolderRepository
    
    init(folderRepository: FolderRepository) {
        self.folderRepository = folderRepository
    }
    
    func createFolder(name: String, parentId: UUID? = nil) async throws -> Folder {
        let folder = Folder(
            name: name,
            parentFolderId: parentId
        )
        
        // 保存処理（実装予定）
        return folder
    }
    
    func getFolders() async throws -> [Folder] {
        // フォルダ取得処理（実装予定）
        return []
    }
    
    func deleteFolder(id: UUID) async throws {
        // フォルダ削除処理（実装予定）
    }
}

// MARK: - Manage Tags Use Case
class ManageTagsUseCase {
    private let tagRepository: TagRepository
    
    init(tagRepository: TagRepository) {
        self.tagRepository = tagRepository
    }
    
    func createTag(name: String, color: String = "#4A90A4") async throws -> Tag {
        let tag = Tag(name: name, color: color)
        
        // 保存処理（実装予定）
        return tag
    }
    
    func getTags() async throws -> [Tag] {
        // タグ取得処理（実装予定）
        return Tag.defaultTags
    }
    
    func deleteTag(id: UUID) async throws {
        // タグ削除処理（実装予定）
    }
    
    func updateTagUsage(id: UUID) async throws {
        // タグ使用回数更新（実装予定）
    }
}

// MARK: - Manage Templates Use Case
class ManageTemplatesUseCase {
    private let templateRepository: TemplateRepository
    
    init(templateRepository: TemplateRepository) {
        self.templateRepository = templateRepository
    }
    
    func createTemplate(
        name: String,
        type: RecordType,
        settings: RecordingSettings
    ) async throws -> RecordTemplate {
        let template = RecordTemplate(
            name: name,
            recordType: type,
            duration: settings.duration,
            cropRect: settings.cropRect,
            tagIds: settings.tagIds,
            folderId: settings.folderId
        )
        
        // 保存処理（実装予定）
        return template
    }
    
    func getTemplates() async throws -> [RecordTemplate] {
        // テンプレート取得処理（実装予定）
        return RecordTemplate.defaultTemplates
    }
    
    func updateTemplateUsage(id: UUID) async throws {
        // テンプレート使用回数更新（実装予定）
    }
    
    func deleteTemplate(id: UUID) async throws {
        // テンプレート削除処理（実装予定）
    }
}

// MARK: - Error Types
enum UseCaseError: Error, LocalizedError {
    case recordNotFound
    case invalidFileType
    case insufficientStorage
    case permissionDenied
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .recordNotFound:
            return "記録が見つかりません"
        case .invalidFileType:
            return "サポートされていないファイル形式です"
        case .insufficientStorage:
            return "ストレージ容量が不足しています"
        case .permissionDenied:
            return "必要な権限が許可されていません"
        case .networkError:
            return "ネットワークエラーが発生しました"
        }
    }
}