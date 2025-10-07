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
        // Create model container with proper configuration
        do {
            let schema = Schema([Receipt.self, ReceiptItem.self, Budget.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            print("✅ Model container initialized successfully")
        } catch {
            print("❌ Failed to initialize model container: \(error)")

            // If migration fails, delete the old store and recreate
            if let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("default.store") {
                print("⚠️ Attempting to delete corrupted store at \(storeURL)")
                try? FileManager.default.removeItem(at: storeURL)

                // Also remove associated files
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-shm"))
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("store-wal"))

                // Retry creation
                do {
                    let schema = Schema([Receipt.self, ReceiptItem.self, Budget.self])
                    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                    modelContainer = try ModelContainer(for: schema, configurations: [config])
                    print("✅ Model container initialized successfully after store deletion")
                    return
                } catch {
                    print("❌ Failed to initialize model container after deletion: \(error)")
                    fatalError("Could not initialize ModelContainer: \(error)")
                }
            }

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
