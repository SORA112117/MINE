import SwiftUI

struct RecordingView: View {
    @StateObject var viewModel: RecordingViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        VStack(spacing: Constants.UI.padding) {
            Text("\(viewModel.recordType.displayName)を記録")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Theme.text)
            
            Text("記録画面（実装予定）")
                .font(.body)
                .foregroundColor(Theme.gray5)
            
            // プレースホルダーカメラビュー
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .fill(Theme.gray2)
                .frame(height: 300)
                .overlay(
                    VStack {
                        Image(systemName: viewModel.recordType.systemImage)
                            .font(.system(size: 60))
                            .foregroundColor(Theme.gray4)
                        
                        Text("\(viewModel.recordType.displayName)記録エリア")
                            .font(.headline)
                            .foregroundColor(Theme.gray5)
                            .padding(.top)
                    }
                )
                .padding()
            
            // 記録ボタン
            Button {
                // 記録開始/停止の処理（実装予定）
            } label: {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "record.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle(viewModel.recordType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    appCoordinator.dismissSheet()
                }
            }
        }
    }
}

// Placeholder ViewModel
@MainActor
class RecordingViewModel: ObservableObject {
    let recordType: RecordType
    
    private let createRecordUseCase: CreateRecordUseCase
    private let mediaService: MediaService
    private let manageTemplatesUseCase: ManageTemplatesUseCase
    
    init(
        recordType: RecordType,
        createRecordUseCase: CreateRecordUseCase,
        mediaService: MediaService,
        manageTemplatesUseCase: ManageTemplatesUseCase
    ) {
        self.recordType = recordType
        self.createRecordUseCase = createRecordUseCase
        self.mediaService = mediaService
        self.manageTemplatesUseCase = manageTemplatesUseCase
    }
}