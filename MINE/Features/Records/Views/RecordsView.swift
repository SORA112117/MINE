import SwiftUI

struct RecordsView: View {
    @StateObject var viewModel: RecordsViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        VStack {
            Text("記録")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Theme.text)
            
            Text("記録一覧画面（実装予定）")
                .font(.body)
                .foregroundColor(Theme.gray5)
                .padding()
            
            // プレースホルダーコンテンツ
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 3),
                spacing: Constants.UI.smallPadding
            ) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: Constants.UI.smallCornerRadius)
                        .fill(Theme.gray2)
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(Theme.gray4)
                                Text("記録 \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(Theme.gray5)
                            }
                        )
                }
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("記録")
        .navigationBarTitleDisplayMode(.large)
        .background(Theme.background)
    }
}

// Placeholder ViewModel
@MainActor
class RecordsViewModel: ObservableObject {
    private let getRecordsUseCase: GetRecordsUseCase
    private let deleteRecordUseCase: DeleteRecordUseCase
    private let manageFoldersUseCase: ManageFoldersUseCase
    private let manageTagsUseCase: ManageTagsUseCase
    
    init(
        getRecordsUseCase: GetRecordsUseCase,
        deleteRecordUseCase: DeleteRecordUseCase,
        manageFoldersUseCase: ManageFoldersUseCase,
        manageTagsUseCase: ManageTagsUseCase
    ) {
        self.getRecordsUseCase = getRecordsUseCase
        self.deleteRecordUseCase = deleteRecordUseCase
        self.manageFoldersUseCase = manageFoldersUseCase
        self.manageTagsUseCase = manageTagsUseCase
    }
}