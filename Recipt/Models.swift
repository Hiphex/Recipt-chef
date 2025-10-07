import Foundation
import SwiftData

// MARK: - Receipt Model
@Model
final class Receipt {
    var id: UUID
    var date: Date
    var storeName: String
    var totalAmount: Double
    var category: Category
    var imageData: Data?
    var items: [ReceiptItem]
    var rawText: String?
    var tags: [String]
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        storeName: String = "",
        totalAmount: Double = 0.0,
        category: Category = .other,
        imageData: Data? = nil,
        items: [ReceiptItem] = [],
        rawText: String? = nil,
        tags: [String] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.storeName = storeName
        self.totalAmount = totalAmount
        self.category = category
        self.imageData = imageData
        self.items = items
        self.rawText = rawText
        self.tags = tags
        self.notes = notes
    }
}

// MARK: - Receipt Item Model
@Model
final class ReceiptItem {
    var id: UUID
    var name: String
    var price: Double
    var quantity: Int

    init(
        id: UUID = UUID(),
        name: String,
        price: Double,
        quantity: Int = 1
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.quantity = quantity
    }
}

// MARK: - Category Enum
enum Category: String, Codable, CaseIterable {
    case groceries = "Groceries"
    case dining = "Dining"
    case shopping = "Shopping"
    case transport = "Transport"
    case entertainment = "Entertainment"
    case health = "Health"
    case utilities = "Utilities"
    case other = "Other"

    var icon: String {
        switch self {
        case .groceries: return "cart.fill"
        case .dining: return "fork.knife"
        case .shopping: return "bag.fill"
        case .transport: return "car.fill"
        case .entertainment: return "tv.fill"
        case .health: return "heart.fill"
        case .utilities: return "bolt.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .groceries: return "green"
        case .dining: return "orange"
        case .shopping: return "pink"
        case .transport: return "blue"
        case .entertainment: return "purple"
        case .health: return "red"
        case .utilities: return "yellow"
        case .other: return "gray"
        }
    }
}

// MARK: - Budget Model
@Model
final class Budget {
    var id: UUID
    var category: Category
    var monthlyLimit: Double
    var currentSpending: Double
    var month: Date // First day of the month

    var remainingBudget: Double {
        monthlyLimit - currentSpending
    }

    var percentageUsed: Double {
        guard monthlyLimit > 0 else { return 0 }
        return (currentSpending / monthlyLimit) * 100
    }

    var isOverBudget: Bool {
        currentSpending > monthlyLimit
    }

    init(
        id: UUID = UUID(),
        category: Category,
        monthlyLimit: Double,
        currentSpending: Double = 0.0,
        month: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.currentSpending = currentSpending
        self.month = month
    }
}
