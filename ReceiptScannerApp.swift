import SwiftUI
import SwiftData

@main
struct ReceiptScannerApp: App {
    var body: some Scene {
        WindowGroup {
            ReceiptListView()
        }
        .modelContainer(for: [Receipt.self, ReceiptItem.self, Budget.self])
    }
}
