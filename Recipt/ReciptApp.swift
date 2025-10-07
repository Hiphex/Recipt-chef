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

    init() {
        ValueTransformer.setValueTransformer(
            TagsValueTransformer(),
            forName: .tagsValueTransformerName
        )
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(for: [Receipt.self, ReceiptItem.self, Budget.self])
    }
}
