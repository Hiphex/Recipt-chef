import SwiftUI
import SwiftData

// MARK: - Budget Detail View
struct BudgetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: Budget
    @Query private var allReceipts: [Receipt]

    @State private var isEditingLimit = false
    @State private var newLimit: Double = 0

    private var categoryReceipts: [Receipt] {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return allReceipts
            .filter { receipt in
                receipt.category == budget.category &&
                calendar.component(.month, from: receipt.date) == currentMonth &&
                calendar.component(.year, from: receipt.date) == currentYear
            }
            .sorted { $0.date > $1.date }
    }

    private var currentSpending: Double {
        categoryReceipts.reduce(0.0) { $0 + $1.totalAmount }
    }

    private var percentageUsed: Double {
        guard budget.monthlyLimit > 0 else { return 0 }
        return (currentSpending / budget.monthlyLimit) * 100
    }

    private var remaining: Double {
        budget.monthlyLimit - currentSpending
    }

    private var isOverBudget: Bool {
        currentSpending > budget.monthlyLimit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Budget Overview Card
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: budget.category.icon)
                            .font(.largeTitle)
                            .foregroundStyle(categoryColor(budget.category.color))

                        VStack(alignment: .leading) {
                            Text(budget.category.rawValue)
                                .font(.title2)
                                .bold()

                            Text("Monthly Budget")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    // Spending Amount
                    VStack(spacing: 8) {
                        Text("$\(currentSpending, specifier: "%.2f")")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(isOverBudget ? .red : .primary)

                        Text("of $\(budget.monthlyLimit, specifier: "%.2f")")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Progress Bar
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 16)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(progressColor)
                                    .frame(
                                        width: min(geometry.size.width * CGFloat(percentageUsed / 100), geometry.size.width),
                                        height: 16
                                    )
                            }
                        }
                        .frame(height: 16)

                        HStack {
                            if isOverBudget {
                                Label("Over by $\(abs(remaining), specifier: "%.2f")", systemImage: "exclamationmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            } else {
                                Text("$\(remaining, specifier: "%.2f") remaining")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(Int(percentageUsed))%")
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(progressColor)
                        }
                    }

                    // Edit Budget Button
                    Button {
                        newLimit = budget.monthlyLimit
                        isEditingLimit = true
                    } label: {
                        Label("Edit Budget Limit", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                .padding(.horizontal)

                // Receipts in this category
                VStack(alignment: .leading, spacing: 12) {
                    Text("Receipts This Month")
                        .font(.title3)
                        .bold()
                        .padding(.horizontal)

                    if categoryReceipts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "receipt")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No receipts in this category yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(categoryReceipts) { receipt in
                                NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                                    ReceiptRow(receipt: receipt)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                if receipt.id != categoryReceipts.last?.id {
                                    Divider()
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(budget.category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingLimit) {
            EditBudgetLimitView(budget: budget, newLimit: $newLimit)
        }
    }

    private var progressColor: Color {
        if isOverBudget {
            return .red
        } else if percentageUsed >= 90 {
            return .orange
        } else if percentageUsed >= 75 {
            return .yellow
        } else {
            return .green
        }
    }

    private func categoryColor(_ colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "blue": return .blue
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Edit Budget Limit Sheet
struct EditBudgetLimitView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: Budget
    @Binding var newLimit: Double

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Limit") {
                    HStack {
                        Text("$")
                        TextField("Amount", value: $newLimit, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Save Changes") {
                        budget.monthlyLimit = newLimit
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
