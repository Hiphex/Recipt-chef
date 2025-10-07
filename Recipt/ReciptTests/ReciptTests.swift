//
//  ReciptTests.swift
//  ReciptTests
//
//  Created by Jake Cella on 10/5/25.
//

import Foundation
import Testing
@testable import Recipt

struct ReciptTests {

    // MARK: - Receipt Parsing

    @Test func parseReceiptExtractsKeyInformation() async throws {
        let sampleText = """
        Trader Joe's
        123 Market Street
        Date: 05/10/2024

        Bananas        1.99
        Almond Milk    $3.49
        Organic Eggs   4.99
        SUBTOTAL       10.47
        Tax            $0.84
        TOTAL          $11.31
        """

        let service = ReceiptScannerService.shared
        let parsed = service.parseReceipt(from: sampleText)

        #expect(parsed.storeName == "Trader Joe's")
        #expect(parsed.items.count == 3)
        #expect(parsed.items.contains(where: { $0.name == "Bananas" && abs($0.price - 1.99) < 0.01 }))
        #expect(parsed.items.contains(where: { $0.name == "Almond Milk" && abs($0.price - 3.49) < 0.01 }))
        #expect(abs(parsed.total - 11.31) < 0.01)
    }

    @Test func categorizeReceiptUsesStoreKeywords() async throws {
        let service = ReceiptScannerService.shared
        let items = [ReceiptItem(name: "Latte", price: 4.95)]

        let category = service.categorizeReceipt(storeName: "Starbucks Coffee", items: items)

        #expect(category == .dining)
    }

    @Test func categorizeReceiptFallsBackToItems() async throws {
        let service = ReceiptScannerService.shared
        let items = [ReceiptItem(name: "Whole Grain Bread", price: 3.49)]

        let category = service.categorizeReceipt(storeName: "Neighborhood Shop", items: items)

        #expect(category == .groceries)
    }

    // MARK: - Export Service

    @Test func exportToCSVOrdersReceiptsAndFormatsFields() async throws {
        let exportService = ExportService.shared

        let calendar = Calendar(identifier: .gregorian)
        let firstDate = calendar.date(from: DateComponents(year: 2024, month: 5, day: 10)) ?? Date()
        let secondDate = calendar.date(from: DateComponents(year: 2024, month: 5, day: 11)) ?? Date()

        let groceryItems = [
            ReceiptItem(name: "Apples", price: 3.25),
            ReceiptItem(name: "Almond Butter", price: 12.75)
        ]
        let restaurantItems = [ReceiptItem(name: "Lunch Special", price: 18.50)]

        let receipts = [
            Receipt(
                date: secondDate,
                storeName: "Bistro Central",
                totalAmount: 18.50,
                category: .dining,
                items: restaurantItems
            ),
            Receipt(
                date: firstDate,
                storeName: "Green Valley Market",
                totalAmount: 16.00,
                category: .groceries,
                items: groceryItems
            )
        ]

        guard let url = exportService.exportToCSV(receipts: receipts) else {
            Issue.record("Expected CSV URL to be created")
            return
        }

        let csv = try String(contentsOf: url)
        let rows = csv.split(separator: "\n")

        #expect(rows.first == "Date,Store,Category,Total,Items")
        #expect(rows.count == 3)
        #expect(rows[1].contains("Green Valley Market"))
        #expect(rows[1].contains("Apples; Almond Butter"))
        #expect(rows[2].contains("Bistro Central"))
    }

    // MARK: - Analytics Service

    @Test func generateSpendingInsightsRequiresAPIKey() async throws {
        do {
            _ = try await awaitResult { completion in
                SpendingAnalyticsService.shared.generateSpendingInsights(
                    receipts: [],
                    budgets: [],
                    completion: completion
                )
            }
            Issue.record("Expected missing API key error to be thrown")
        } catch {
            guard let analyticsError = error as? AnalyticsError else {
                Issue.record("Unexpected error type: \(error)")
                return
            }

            #expect(analyticsError == .missingAPIKey)
        }
    }

    // MARK: - Helpers

    private func awaitResult<T>(
        _ body: (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            body { result in
                continuation.resume(with: result)
            }
        }
    }
}
