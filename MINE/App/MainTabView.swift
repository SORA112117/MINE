import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var diContainer: DIContainer
    
    var body: some View {
        TabView(selection: $appCoordinator.selectedTab) {
            // ホームタブ
            NavigationStack(path: $appCoordinator.navigationPath) {
                HomeView(viewModel: diContainer.makeHomeViewModel())
            }
            .tabItem {
                Label(Tab.home.title, systemImage: Tab.home.systemImage)
            }
            .tag(Tab.home)
            
            // 記録タブ
            NavigationStack(path: $appCoordinator.navigationPath) {
                RecordsView(viewModel: diContainer.makeRecordsViewModel())
            }
            .tabItem {
                Label(Tab.records.title, systemImage: Tab.records.systemImage)
            }
            .tag(Tab.records)
            
            // 設定タブ
            NavigationStack(path: $appCoordinator.navigationPath) {
                SettingsView(viewModel: diContainer.makeSettingsViewModel())
            }
            .tabItem {
                Label(Tab.settings.title, systemImage: Tab.settings.systemImage)
            }
            .tag(Tab.settings)
        }
        .accentColor(Theme.primary)
        .sheet(item: $appCoordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(
            appCoordinator.alertTitle,
            isPresented: $appCoordinator.showingAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appCoordinator.alertMessage)
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: Sheet) -> some View {
        switch sheet {
        case .recording(let type):
            NavigationStack {
                RecordingView(
                    viewModel: diContainer.makeRecordingViewModel(recordType: type)
                )
            }
            
        case .recordDetail(let record):
            NavigationStack {
                RecordDetailView(record: record)
            }
            
        case .folderPicker:
            NavigationStack {
                FolderPickerView()
            }
            
        case .tagEditor:
            NavigationStack {
                TagEditorView()
            }
            
        case .templateEditor(let template):
            NavigationStack {
                TemplateEditorView(template: template)
            }
            
        case .subscription:
            NavigationStack {
                SubscriptionView()
            }
        }
    }
}