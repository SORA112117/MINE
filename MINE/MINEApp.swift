//
//  MINEApp.swift
//  MINE
//
//  Created by 山内壮良 on 2025/09/02.
//

import SwiftUI

@main
struct MINEApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var diContainer = DIContainer()
    
    init() {
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appCoordinator)
                .environmentObject(diContainer)
                .onAppear {
                    setupInitialData()
                }
        }
    }
    
    private func setupAppearance() {
        // ナビゲーションバーの外観設定
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Theme.background)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.text)]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        
        // タブバーの外観設定
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Theme.background)
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        
        // タブバーアイテムの色設定
        UITabBar.appearance().tintColor = UIColor(Theme.primary)
        UITabBar.appearance().unselectedItemTintColor = UIColor(Theme.gray4)
    }
    
    private func setupInitialData() {
        // Keychainサービスの初期化とUserDefaultsからの移行
        do {
            KeychainService.shared.migrateFromUserDefaults()
        } catch {
            print("Failed to migrate from UserDefaults: \(error)")
        }
        
        // 初回起動時の設定
        if !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding) {
            // デフォルトフォルダとタグを作成
            do {
                try createDefaultData()
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)
            } catch {
                print("Failed to create default data: \(error)")
                // 初期データ作成に失敗しても、アプリを継続起動
            }
        }
        
        // サブスクリプション状態の検証（バックグラウンドで実行）
        Task.detached {
            do {
                await KeychainService.shared.validateSubscription()
            } catch {
                print("Failed to validate subscription: \(error)")
            }
        }
    }
    
    private func createDefaultData() throws {
        let context = CoreDataStack.shared.viewContext
        
        // デフォルトフォルダ作成
        for defaultFolder in Folder.defaultFolders {
            do {
                let entity = defaultFolder.toEntity(context: context)
                entity.id = defaultFolder.id
            } catch {
                print("Failed to create folder entity for \(defaultFolder.name): \(error)")
                throw error
            }
        }
        
        // デフォルトタグ作成
        for defaultTag in Tag.defaultTags {
            do {
                let entity = defaultTag.toEntity(context: context)
                entity.id = defaultTag.id
            } catch {
                print("Failed to create tag entity for \(defaultTag.name): \(error)")
                throw error
            }
        }
        
        // コンテキストの保存
        do {
            try context.save()
        } catch {
            print("Failed to save default data: \(error)")
            throw error
        }
    }
}
