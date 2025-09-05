import Foundation
import SwiftUI

// MARK: - Dependency Injection Container
@MainActor
class DIContainer: ObservableObject {
    
    // MARK: - Services
    lazy var mediaService: MediaService = {
        MediaService()
    }()
    
    lazy var subscriptionService: SubscriptionService = {
        SubscriptionService()
    }()
    
    lazy var cloudSyncService: CloudSyncService = {
        CloudSyncService(coreDataStack: coreDataStack)
    }()
    
    // MARK: - Repositories
    lazy var recordRepository: RecordRepository = {
        RecordRepository(
            localDataSource: localDataSource,
            cloudDataSource: cloudDataSource
        )
    }()
    
    
    lazy var tagRepository: TagRepository = {
        TagRepository(coreDataStack: coreDataStack)
    }()
    
    lazy var templateRepository: TemplateRepository = {
        TemplateRepository(coreDataStack: coreDataStack)
    }()
    
    // MARK: - Data Sources
    lazy var localDataSource: LocalDataSource = {
        LocalDataSource(coreDataStack: coreDataStack)
    }()
    
    lazy var cloudDataSource: CloudDataSource = {
        CloudDataSource()
    }()
    
    // MARK: - Core Data
    lazy var coreDataStack: CoreDataStack = {
        CoreDataStack.shared
    }()
    
    // MARK: - Use Cases
    lazy var createRecordUseCase: CreateRecordUseCase = {
        CreateRecordUseCase(
            recordRepository: recordRepository,
            mediaService: mediaService
        )
    }()
    
    lazy var getRecordsUseCase: GetRecordsUseCase = {
        GetRecordsUseCase(recordRepository: recordRepository)
    }()
    
    lazy var deleteRecordUseCase: DeleteRecordUseCase = {
        DeleteRecordUseCase(
            recordRepository: recordRepository,
            mediaService: mediaService
        )
    }()
    
    lazy var updateRecordUseCase: UpdateRecordUseCase = {
        UpdateRecordUseCase(
            recordRepository: recordRepository,
            manageTagsUseCase: manageTagsUseCase
        )
    }()
    
    
    lazy var manageTagsUseCase: ManageTagsUseCase = {
        ManageTagsUseCase(tagRepository: tagRepository)
    }()
    
    lazy var manageTemplatesUseCase: ManageTemplatesUseCase = {
        ManageTemplatesUseCase(templateRepository: templateRepository)
    }()
    
    // MARK: - ViewModels
    lazy var recordsViewModel: RecordsViewModel = {
        RecordsViewModel(
            getRecordsUseCase: getRecordsUseCase,
            deleteRecordUseCase: deleteRecordUseCase,
            manageTagsUseCase: manageTagsUseCase
        )
    }()
    
    // MARK: - ViewModels Factory
    @MainActor
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getRecordsUseCase: getRecordsUseCase,
            createRecordUseCase: createRecordUseCase
        )
    }
    
    @MainActor
    func makeRecordsViewModel() -> RecordsViewModel {
        return recordsViewModel
    }
    
    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            subscriptionService: subscriptionService,
            cloudSyncService: cloudSyncService,
            coreDataStack: coreDataStack
        )
    }
    
    @MainActor
    func makeRecordingViewModel(recordType: RecordType) -> RecordingViewModel {
        RecordingViewModel(
            recordType: recordType,
            createRecordUseCase: createRecordUseCase,
            mediaService: mediaService,
            manageTemplatesUseCase: manageTemplatesUseCase
        )
    }
    
    @MainActor
    func makeRecordDetailViewModel(record: Record) -> RecordDetailViewModel {
        RecordDetailViewModel(
            record: record,
            updateRecordUseCase: updateRecordUseCase,
            manageTagsUseCase: manageTagsUseCase
        )
    }
}