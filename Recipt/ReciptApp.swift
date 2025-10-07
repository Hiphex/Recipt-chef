//
//  ReciptApp.swift
//  Recipt
//
//  Created by Jake Cella on 10/5/25.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct ReciptApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    let modelContainer: ModelContainer

    init() {
        // Delete any existing CoreData/SwiftData stores to ensure clean migration
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let storeURL = appSupportURL.appendingPathComponent("default.store")

            // Check if old store exists and delete it
            if FileManager.default.fileExists(atPath: storeURL.path) {
                print("🗑️ Removing old data store for clean migration...")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
            }
        }

        // Create model container with proper configuration
        do {
            let schema = Schema([Receipt.self, ReceiptItem.self, Budget.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            print("✅ Model container initialized successfully")
        } catch {
            print("❌ Failed to initialize model container: \(error)")
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(modelContainer)
    }
}
