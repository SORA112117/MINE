import SwiftUI
import Foundation

// MARK: - Tab Types
enum Tab: String, CaseIterable {
    case home = "home"
    case records = "records"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .home: return "ホーム"
        case .records: return "記録"
        case .settings: return "設定"
        }
    }
    
    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .records: return "folder.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Sheet Types
enum Sheet: Identifiable {
    case recording(RecordType)
    case recordDetail(Record)
    case tagEditor
    case templateEditor(RecordTemplate?)
    case subscription
    
    var id: String {
        switch self {
        case .recording(let type): return "recording_\(type.rawValue)"
        case .recordDetail(let record): return "record_\(record.id.uuidString)"
        case .tagEditor: return "tag_editor"
        case .templateEditor(let template): return "template_\(template?.id.uuidString ?? "new")"
        case .subscription: return "subscription"
        }
    }
}

// MARK: - App Coordinator
class AppCoordinator: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var presentedSheet: Sheet?
    @Published var navigationPath = NavigationPath()
    @Published var showingAlert = false
    @Published var alertMessage = ""
    @Published var alertTitle = ""
    
    // Navigation Methods
    func showHome() {
        selectedTab = .home
        navigationPath = NavigationPath()
    }
    
    func showRecords() {
        selectedTab = .records
        navigationPath = NavigationPath()
    }
    
    func showSettings() {
        selectedTab = .settings
        navigationPath = NavigationPath()
    }
    
    // Sheet Presentation
    func showRecording(type: RecordType) {
        presentedSheet = .recording(type)
    }
    
    func showRecordDetail(_ record: Record) {
        presentedSheet = .recordDetail(record)
    }
    
    
    func showTagEditor() {
        presentedSheet = .tagEditor
    }
    
    func showTemplateEditor(_ template: RecordTemplate? = nil) {
        presentedSheet = .templateEditor(template)
    }
    
    func showSubscription() {
        presentedSheet = .subscription
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
    // Alert Presentation
    func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    func showError(_ error: Error) {
        showAlert(
            title: "エラーが発生しました",
            message: error.localizedDescription
        )
    }
    
    // Navigation Stack
    func push<T: Hashable>(_ value: T) {
        navigationPath.append(value)
    }
    
    func popToRoot() {
        navigationPath = NavigationPath()
    }
    
    func pop() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}