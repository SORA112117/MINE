import Foundation
import Security

// MARK: - Keychain Service
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Constants
    private struct Constants {
        static let service = "com.mine.app.keychain"
        static let isProVersionKey = "isProVersion"
        static let subscriptionReceiptKey = "subscriptionReceipt"
        static let subscriptionExpiryKey = "subscriptionExpiry"
        static let lastValidationKey = "lastValidation"
    }
    
    // MARK: - Keychain Error Types
    enum KeychainError: Error, LocalizedError {
        case duplicateItem
        case itemNotFound
        case invalidData
        case unexpectedError(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "アイテムが既に存在します"
            case .itemNotFound:
                return "アイテムが見つかりません"
            case .invalidData:
                return "無効なデータです"
            case .unexpectedError(let status):
                return "予期しないエラー: \(status)"
            }
        }
    }
    
    // MARK: - Pro Version Management
    
    /// Pro版ステータスを安全に取得
    var isProVersion: Bool {
        get {
            do {
                let data = try getData(for: Constants.isProVersionKey)
                let value = try JSONDecoder().decode(Bool.self, from: data)
                
                // 有効期限もチェック
                if let expiryData = try? getData(for: Constants.subscriptionExpiryKey),
                   let expiry = try? JSONDecoder().decode(Date.self, from: expiryData) {
                    return value && expiry > Date()
                }
                
                return value
            } catch {
                // エラー時はfalse（安全側に倒す）
                return false
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                try setData(data, for: Constants.isProVersionKey)
                
                // Pro版に設定する場合は検証タイムスタンプも更新
                if newValue {
                    let validationData = try JSONEncoder().encode(Date())
                    try setData(validationData, for: Constants.lastValidationKey)
                }
            } catch {
                print("Failed to store Pro version status: \(error)")
            }
        }
    }
    
    /// サブスクリプション有効期限を設定
    func setSubscriptionExpiry(_ expiry: Date) throws {
        let data = try JSONEncoder().encode(expiry)
        try setData(data, for: Constants.subscriptionExpiryKey)
    }
    
    /// サブスクリプション有効期限を取得
    func getSubscriptionExpiry() -> Date? {
        do {
            let data = try getData(for: Constants.subscriptionExpiryKey)
            return try JSONDecoder().decode(Date.self, from: data)
        } catch {
            return nil
        }
    }
    
    /// レシートデータを安全に保存
    func setReceiptData(_ receipt: Data) throws {
        try setData(receipt, for: Constants.subscriptionReceiptKey)
    }
    
    /// レシートデータを取得
    func getReceiptData() -> Data? {
        do {
            return try getData(for: Constants.subscriptionReceiptKey)
        } catch {
            return nil
        }
    }
    
    /// サブスクリプション情報をクリア（ログアウト時など）
    func clearSubscriptionData() {
        do {
            try deleteData(for: Constants.isProVersionKey)
            try deleteData(for: Constants.subscriptionReceiptKey)
            try deleteData(for: Constants.subscriptionExpiryKey)
            try deleteData(for: Constants.lastValidationKey)
        } catch {
            print("Failed to clear subscription data: \(error)")
        }
    }
    
    // MARK: - Private Keychain Operations
    
    private func setData(_ data: Data, for key: String) throws {
        // 既存データを削除してから新規追加
        try? deleteData(for: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    private func getData(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedError(status)
        }
    }
    
    private func deleteData(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    // MARK: - Migration from UserDefaults
    
    /// UserDefaultsからKeychainへのマイグレーション
    func migrateFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        
        // Pro版ステータスの移行
        if userDefaults.object(forKey: MINE.Constants.UserDefaultsKeys.isProVersion) != nil {
            let isProFromDefaults = userDefaults.bool(forKey: MINE.Constants.UserDefaultsKeys.isProVersion)
            
            // Keychainにまだ保存されていない場合のみ移行
            if (try? getData(for: Constants.isProVersionKey)) == nil {
                isProVersion = isProFromDefaults
                
                // 移行完了後、UserDefaultsから削除
                userDefaults.removeObject(forKey: MINE.Constants.UserDefaultsKeys.isProVersion)
            }
        }
    }
    
    // MARK: - Subscription Validation
    
    /// サブスクリプションの有効性を検証
    func validateSubscription() async -> Bool {
        // レシートベース検証（将来的にサーバーサイド検証に拡張可能）
        guard let receiptData = getReceiptData() else {
            isProVersion = false
            return false
        }
        
        // 有効期限チェック
        if let expiry = getSubscriptionExpiry(), expiry <= Date() {
            isProVersion = false
            return false
        }
        
        // 最後の検証から24時間以上経過している場合は再検証
        let shouldRevalidate: Bool
        if let lastValidationData = try? getData(for: Constants.lastValidationKey),
           let lastValidation = try? JSONDecoder().decode(Date.self, from: lastValidationData) {
            shouldRevalidate = Date().timeIntervalSince(lastValidation) > 86400 // 24時間
        } else {
            shouldRevalidate = true
        }
        
        if shouldRevalidate {
            // 基本的なレシート整合性チェック
            let isValid = validateReceiptIntegrity(receiptData)
            
            if isValid {
                // 検証タイムスタンプ更新
                let validationData = try? JSONEncoder().encode(Date())
                if let data = validationData {
                    try? setData(data, for: Constants.lastValidationKey)
                }
            } else {
                isProVersion = false
                return false
            }
        }
        
        return isProVersion
    }
    
    /// レシートの基本的な整合性チェック（簡易版）
    private func validateReceiptIntegrity(_ receiptData: Data) -> Bool {
        // 実装時はStoreKit2のTransaction検証やサーバーサイド検証を使用
        // 現在は基本的なデータ存在チェックのみ
        return receiptData.count > 0
    }
    
    // MARK: - Debug/Development Support
    
    /// 開発用：Pro版を強制的に有効化（Debugビルドのみ）
    #if DEBUG
    func enableProVersionForDevelopment() {
        isProVersion = true
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        try? setSubscriptionExpiry(futureDate)
        
        // 開発用のダミーレシートデータ
        let dummyReceipt = "development-receipt".data(using: .utf8) ?? Data()
        try? setReceiptData(dummyReceipt)
    }
    
    func disableProVersionForDevelopment() {
        clearSubscriptionData()
    }
    #endif
}