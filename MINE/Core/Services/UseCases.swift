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
        title: String,
        tags: [Tag] = []
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
            title: title,
            tags: Set(tags), // 配列をSetに変換
            templateId: nil
        )
        
        // 保存
        try await recordRepository.save(record)
        
        // 記録保存完了通知を送信
        NotificationCenter.default.post(
            name: .recordSaved,
            object: nil,
            userInfo: ["record": record]
        )
        
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

// MARK: - Update Record Use Case
class UpdateRecordUseCase {
    private let recordRepository: RecordRepository
    private let manageTagsUseCase: ManageTagsUseCase
    
    init(recordRepository: RecordRepository, manageTagsUseCase: ManageTagsUseCase) {
        self.recordRepository = recordRepository
        self.manageTagsUseCase = manageTagsUseCase
    }
    
    
    func updateTags(recordId: UUID, tags: Set<Tag>) async throws {
        guard var record = try await recordRepository.fetchById(recordId) else {
            throw UseCaseError.recordNotFound
        }
        
        let oldTags = record.tags
        
        // Record構造体を更新（tags変更）
        let updatedRecord = Record(
            id: record.id,
            type: record.type,
            createdAt: record.createdAt,
            updatedAt: Date(),
            duration: record.duration,
            fileURL: record.fileURL,
            thumbnailURL: record.thumbnailURL,
            title: record.title,
            tags: tags,
            templateId: record.templateId
        )
        
        try await recordRepository.update(updatedRecord)
        
        // タグの使用回数を更新
        await updateTagUsageCountsAfterChange(oldTags: oldTags, newTags: tags)
    }
    
    func updateTitle(recordId: UUID, title: String) async throws {
        guard var record = try await recordRepository.fetchById(recordId) else {
            throw UseCaseError.recordNotFound
        }
        
        // Record構造体を更新（title変更）
        let updatedRecord = Record(
            id: record.id,
            type: record.type,
            createdAt: record.createdAt,
            updatedAt: Date(),
            duration: record.duration,
            fileURL: record.fileURL,
            thumbnailURL: record.thumbnailURL,
            title: title,
            tags: record.tags,
            templateId: record.templateId
        )
        
        try await recordRepository.update(updatedRecord)
    }
    
    private func updateTagUsageCountsAfterChange(oldTags: Set<Tag>, newTags: Set<Tag>) async {
        // 削除されたタグの使用回数を減らす
        let removedTags = oldTags.subtracting(newTags)
        for tag in removedTags {
            try? await manageTagsUseCase.decrementTagUsage(id: tag.id)
        }
        
        // 追加されたタグの使用回数を増やす
        let addedTags = newTags.subtracting(oldTags)
        for tag in addedTags {
            try? await manageTagsUseCase.incrementTagUsage(id: tag.id)
        }
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
        
        try await tagRepository.save(tag)
        return tag
    }
    
    func getTags() async throws -> [Tag] {
        return try await tagRepository.fetchAll()
    }
    
    func deleteTag(id: UUID) async throws {
        try await tagRepository.delete(id)
    }
    
    func updateTagUsage(id: UUID) async throws {
        try await tagRepository.incrementUsage(id)
    }
    
    func incrementTagUsage(id: UUID) async throws {
        try await tagRepository.incrementUsage(id)
    }
    
    func decrementTagUsage(id: UUID) async throws {
        try await tagRepository.decrementUsage(id)
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
        )
        
        try await templateRepository.save(template)
        return template
    }
    
    func getTemplates() async throws -> [RecordTemplate] {
        return try await templateRepository.fetchAll()
    }
    
    func updateTemplateUsage(id: UUID) async throws {
        try await templateRepository.incrementUsage(id)
    }
    
    func deleteTemplate(id: UUID) async throws {
        try await templateRepository.delete(id)
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