import SwiftUI
import SwiftData

// MARK: - Budget View
struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [Budget]
    @Query private var receipts: [Receipt]

    @State private var showingAddBudget = false

    var body: some View {
        NavigationStack {
            List {
                if budgets.isEmpty {
                    ContentUnavailableView(
                        "No Budgets Set",
                        systemImage: "chart.bar",
                        description: Text("Tap + to create your first budget")
                    )
                } else {
                    ForEach(budgets) { budget in
                        NavigationLink(destination: BudgetDetailView(budget: budget)) {
                            BudgetRow(budget: budget, currentSpending: calculateSpending(for: budget.category))
                        }
                    }
                    .onDelete(perform: deleteBudgets)
                }
            }
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                AddBudgetView()
            }
            .onAppear {
                updateBudgetSpending()
            }
        }
    }

    private func calculateSpending(for category: Category) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return receipts
            .filter { receipt in
                receipt.category == category &&
                calendar.component(.month, from: receipt.date) == currentMonth &&
                calendar.component(.year, from: receipt.date) == currentYear
            }
            .reduce(0.0) { $0 + $1.totalAmount }
    }

    private func updateBudgetSpending() {
        for budget in budgets {
            budget.currentSpending = calculateSpending(for: budget.category)
        }
        try? modelContext.save()
    }

    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(budgets[index])
        }
    }
}

// MARK: - Budget Row
struct BudgetRow: View {
    let budget: Budget
    let currentSpending: Double

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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: budget.category.icon)
                    .foregroundStyle(categoryColor(budget.category.color))

                Text(budget.category.rawValue)
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing) {
                    Text("$\(currentSpending, specifier: "%.0f") / $\(budget.monthlyLimit, specifier: "%.0f")")
                        .font(.subheadline)
                        .bold()

                    if isOverBudget {
                        Text("Over by $\(abs(remaining), specifier: "%.0f")")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("$\(remaining, specifier: "%.0f") left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: min(geometry.size.width * CGFloat(percentageUsed / 100), geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)

            // Warning Message
            if percentageUsed >= 90 && !isOverBudget {
                Label("Almost at limit!", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if isOverBudget {
                Label("Budget exceeded!", systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
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

// MARK: - Add Budget View
struct AddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingBudgets: [Budget]

    @State private var selectedCategory: Category = .groceries
    @State private var monthlyLimit: String = "500"
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Monthly Limit") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $monthlyLimit)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Save Budget") {
                        saveBudget()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(monthlyLimit.isEmpty)
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveBudget() {
        // Check if budget already exists for this category
        if existingBudgets.contains(where: { $0.category == selectedCategory }) {
            errorMessage = "A budget for \(selectedCategory.rawValue) already exists. Please edit the existing budget instead."
            showError = true
            return
        }

        // Validate and parse amount
        guard let amount = Double(monthlyLimit.replacingOccurrences(of: ",", with: "")),
              amount > 0 else {
            errorMessage = "Please enter a valid amount greater than 0"
            showError = true
            return
        }

        let budget = Budget(
            category: selectedCategory,
            monthlyLimit: amount,
            month: Date()
        )

        modelContext.insert(budget)

        do {
            try modelContext.save()
            print("✅ Budget saved successfully: \(selectedCategory.rawValue) - $\(amount)")
            HapticManager.shared.notification(.success)
            dismiss()
        } catch {
            print("❌ Failed to save budget: \(error.localizedDescription)")
            errorMessage = "Failed to save budget: \(error.localizedDescription)"
            showError = true
        }
    }
}
