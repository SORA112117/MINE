import Foundation
import CoreGraphics

struct Constants {
    
    // MARK: - App Info
    struct App {
        static let name = "MINE"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.mine.app"
    }
    
    // MARK: - Storage
    struct Storage {
        static let documentsDirectory: URL = {
            guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                // documentsDirectoryは必ず存在するため、万が一失敗したらクラッシュさせる
                // これは開発時のミスを早期に発見するため
                fatalError("Could not access documents directory. This should never happen.")
            }
            return url
        }()
        
        static let recordsDirectory: URL = {
            return documentsDirectory.appendingPathComponent("Records")
        }()
        
        static let thumbnailsDirectory: URL = {
            return documentsDirectory.appendingPathComponent("Thumbnails")
        }()
        
        static let templatesDirectory: URL = {
            return documentsDirectory.appendingPathComponent("Templates")
        }()
        
        // 無料版のストレージ制限（デバイス容量の10%）
        static func freeVersionStorageLimit() -> Int64 {
            let fileManager = FileManager.default
            do {
                let systemAttributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
                if let totalSpace = systemAttributes[.systemSize] as? Int64 {
                    return totalSpace / 10 // 10%
                }
            } catch {
                print("Error getting system attributes: \(error)")
            }
            return 5_368_709_120 // デフォルト5GB
        }
    }
    
    // MARK: - Recording Limits
    struct RecordingLimits {
        // 無料版
        static let freeVideoMaxDuration: TimeInterval = 5.0 // 5秒
        static let freeAudioMaxDuration: TimeInterval = 90.0 // 1分30秒
        
        // 有料版
        static let proVideoMaxDuration: TimeInterval = 300.0 // 5分
        static let proAudioMaxDuration: TimeInterval = .infinity // 無制限
        
        // 共通
        static let maxCommentLength = 500
        static let maxTagNameLength = 30
        static let maxFolderNameLength = 50
    }
    
    // MARK: - Subscription
    struct Subscription {
        static let monthlyProductID = "com.mine.app.pro.monthly"
        static let yearlyProductID = "com.mine.app.pro.yearly"
        static let monthlyPrice = "¥480"
        static let yearlyPrice = "¥4,800"
    }
    
    // MARK: - Media Quality
    struct MediaQuality {
        // ビデオ品質
        static let freeVideoQuality = "720p"
        static let proVideoQuality = "1080p"
        
        // オーディオ品質
        static let audioBitrate = 256_000 // 256 kbps
        static let audioSampleRate = 44_100.0 // 44.1 kHz
    }
    
    // MARK: - UI
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let smallCornerRadius: CGFloat = 8
        static let largeCornerRadius: CGFloat = 16
        
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        
        static let iconSize: CGFloat = 24
        static let largeIconSize: CGFloat = 32
        
        static let animationDuration: Double = 0.3
        static let longAnimationDuration: Double = 0.5
        
        static let gridColumns = 3
        static let gridSpacing: CGFloat = 8
        
        // Shadow
        static let shadowRadius: CGFloat = 8
        static let shadowOffset = CGSize(width: 0, height: 2)
    }
    
    // MARK: - Cache
    struct Cache {
        static let thumbnailCacheDuration: TimeInterval = 86400 * 7 // 7日
        static let maxCacheSize: Int64 = 500_000_000 // 500MB
    }
    
    // MARK: - Notifications
    struct Notifications {
        static let recordingReminderIdentifier = "recording-reminder"
        static let goalAchievedIdentifier = "goal-achieved"
        static let reviewReminderIdentifier = "review-reminder"
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let isProVersion = "isProVersion"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let currentTheme = "currentTheme"
        static let defaultRecordingDuration = "defaultRecordingDuration"
        static let showGridLines = "showGridLines"
        static let autoSaveTemplate = "autoSaveTemplate"
        static let lastBackupDate = "lastBackupDate"
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let storageFullTitle = "ストレージ容量不足"
        static let storageFullMessage = "デバイスの空き容量が不足しています。不要なファイルを削除してください。"
        
        static let cameraPermissionTitle = "カメラへのアクセス"
        static let cameraPermissionMessage = "カメラを使用するには、設定でカメラへのアクセスを許可してください。"
        
        static let microphonePermissionTitle = "マイクへのアクセス"
        static let microphonePermissionMessage = "録音するには、設定でマイクへのアクセスを許可してください。"
        
        static let networkErrorTitle = "ネットワークエラー"
        static let networkErrorMessage = "インターネット接続を確認してください。"
        
        static let syncErrorTitle = "同期エラー"
        static let syncErrorMessage = "データの同期に失敗しました。後でもう一度お試しください。"
    }
}