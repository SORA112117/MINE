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
        // 初回起動時の設定
        if !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding) {
            // デフォルトフォルダとタグを作成
            createDefaultData()
            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding)
        }
    }
    
    private func createDefaultData() {
        let context = CoreDataStack.shared.viewContext
        
        // デフォルトフォルダ作成
        for defaultFolder in Folder.defaultFolders {
            let entity = defaultFolder.toEntity(context: context)
            entity.id = defaultFolder.id
        }
        
        // デフォルトタグ作成
        for defaultTag in Tag.defaultTags {
            let entity = defaultTag.toEntity(context: context)
            entity.id = defaultTag.id
        }
        
        CoreDataStack.shared.save()
    }
}
