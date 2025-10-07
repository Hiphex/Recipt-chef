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
        // Register the value transformer BEFORE creating the model container
        ValueTransformer.setValueTransformer(
            TagsValueTransformer(),
            forName: .tagsValueTransformerName
        )

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
