import SwiftUI
import SwiftData

// MARK: - Dashboard View
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) private var allReceipts: [Receipt]
    @Query private var budgets: [Budget]
    @State private var showingScanner = false
    @State private var showingAllReceipts = false
    @State private var showingAllBudgets = false
    @State private var showingAddBudget = false
    @State private var showingAnalytics = false
    @State private var isRefreshing = false

    private var recentReceipts: [Receipt] {
        let receipts = Array(allReceipts.prefix(5))
        print(String(repeating: "=", count: 80))
        print("📊 DASHBOARD RECEIPTS QUERY")
        print("Total receipts in DB: \(allReceipts.count)")
        print("Recent receipts shown: \(receipts.count)")
        if !allReceipts.isEmpty {
            print("Latest receipt: \(allReceipts.first?.storeName ?? "nil") - $\(allReceipts.first?.totalAmount ?? 0)")
        }
        print(String(repeating: "=", count: 80))
        return receipts
    }

    private var totalSpentThisMonth: Double {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return allReceipts
            .filter { receipt in
                calendar.component(.month, from: receipt.date) == currentMonth &&
                calendar.component(.year, from: receipt.date) == currentYear
            }
            .reduce(0.0) { $0 + $1.totalAmount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with total spending
                    ZStack {
                        LinearGradient.budgetGradient
                            .ignoresSafeArea(edges: .top)

                        VStack(spacing: 8) {
                            Text("This Month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("$\(totalSpentThisMonth, specifier: "%.2f")")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                                .animation(.smooth, value: totalSpentThisMonth)

                            Text("Total Spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .cardShadow()
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Budgets Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Budgets")
                                .font(.title2)
                                .bold()

                            Spacer()

                            if !budgets.isEmpty {
                                Button("See All") {
                                    showingAllBudgets = true
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)

                        if budgets.isEmpty {
                            Button {
                                showingAddBudget = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Your First Budget")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Array(budgets.prefix(3).enumerated()), id: \.element.id) { index, budget in
                                        NavigationLink(destination: BudgetDetailView(budget: budget)) {
                                            BudgetCard(budget: budget, currentSpending: calculateSpending(for: budget.category))
                                                .frame(width: 280)
                                                .cardAppearance(delay: Double(index) * 0.1)
                                        }
                                        .buttonStyle(.plain)
                                        .simultaneousGesture(TapGesture().onEnded {
                                            HapticManager.shared.impact(.light)
                                        })
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Recent Receipts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Receipts")
                                .font(.title2)
                                .bold()

                            Spacer()

                            if !recentReceipts.isEmpty {
                                Button("See All") {
                                    showingAllReceipts = true
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)

                        if recentReceipts.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "receipt")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)

                                Text("No receipts yet")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                Text("Tap the + button to scan your first receipt")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(recentReceipts) { receipt in
                                    NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                                        ReceiptRow(receipt: receipt)
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)

                                    if receipt.id != recentReceipts.last?.id {
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

                    // AI Analytics Button
                    Button {
                        showingAnalytics = true
                    } label: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AI Insights")
                                    .font(.headline)
                                Text("Analyze your spending")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .cardShadow()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    Spacer(minLength: 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Receipt Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingAllBudgets = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .imageScale(.medium)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScanReceiptView()
            }
            .sheet(isPresented: $showingAllReceipts) {
                ReceiptListView()
            }
            .sheet(isPresented: $showingAllBudgets) {
                BudgetView()
            }
            .sheet(isPresented: $showingAddBudget) {
                AddBudgetView()
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView()
            }
            .refreshable {
                await performRefresh()
            }
        }
    }

    private func calculateSpending(for category: Category) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Create a safe copy to avoid crashes during deletion
        let receiptsCopy = Array(allReceipts)

        let matchingReceipts = receiptsCopy.filter { receipt in
            receipt.category == category &&
            calendar.component(.month, from: receipt.date) == currentMonth &&
            calendar.component(.year, from: receipt.date) == currentYear
        }

        return matchingReceipts.reduce(0.0) { $0 + $1.totalAmount }
    }

    private func performRefresh() async {
        isRefreshing = true
        HapticManager.shared.impact(.light)

        // Simulate refresh delay
        try? await Task.sleep(nanoseconds: 500_000_000)

        isRefreshing = false
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Budget Card Component
struct BudgetCard: View {
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
        ZStack {
            LinearGradient.categoryGradient(for: categoryColor(budget.category.color))

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(categoryColor(budget.category.color).opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: budget.category.icon)
                            .font(.title3)
                            .foregroundStyle(categoryColor(budget.category.color))
                    }

                    Text(budget.category.rawValue)
                        .font(.headline)

                    Spacer()
                }

                // Amount
                VStack(alignment: .leading, spacing: 4) {
                    Text("$\(currentSpending, specifier: "%.0f")")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())

                    Text("of $\(budget.monthlyLimit, specifier: "%.0f")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Progress Bar
                AnimatedProgressBar(
                    progress: percentageUsed,
                    color: progressColor,
                    height: 8
                )

                // Status
                if isOverBudget {
                    Label("Over by $\(abs(remaining), specifier: "%.0f")", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if percentageUsed >= 90 {
                    Label("$\(remaining, specifier: "%.0f") remaining", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("$\(remaining, specifier: "%.0f") remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .cardShadow()
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
