import SwiftUI
import SwiftData
import Charts

// MARK: - Analytics View
struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Receipt.date, order: .reverse) private var allReceipts: [Receipt]
    @Query private var budgets: [Budget]

    @State private var insights: SpendingInsights?
    @State private var trends: TrendAnalysis?
    @State private var isLoadingInsights = false
    @State private var isLoadingTrends = false
    @State private var selectedTimeframe: AnalyticsTimeframe = .month
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)

                        Text("AI Spending Insights")
                            .font(.title2)
                            .bold()

                        Text("Powered by GPT-5-nano")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Timeframe Picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        Text("Week").tag(AnalyticsTimeframe.week)
                        Text("Month").tag(AnalyticsTimeframe.month)
                        Text("3 Months").tag(AnalyticsTimeframe.threeMonths)
                        Text("6 Months").tag(AnalyticsTimeframe.sixMonths)
                        Text("Year").tag(AnalyticsTimeframe.year)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedTimeframe) { _, _ in
                        loadTrends()
                    }

                    // Chart Section
                    if !allReceipts.isEmpty {
                        SpendingChartView(receipts: filteredReceipts)
                            .frame(height: 220)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .cardShadow()
                            .padding(.horizontal)
                    }

                    // AI Insights Section
                    if isLoadingInsights {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Analyzing your spending...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("GPT-5-nano is processing your data")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .cardShadow()
                        .padding(.horizontal)
                    } else if let insights = insights {
                        InsightsSection(insights: insights)
                    }

                    // Trends Section
                    if isLoadingTrends {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Analyzing trends...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .cardShadow()
                        .padding(.horizontal)
                    } else if let trends = trends {
                        TrendsSection(trends: trends)
                    }

                    // Refresh Button
                    Button {
                        refreshAnalytics()
                    } label: {
                        Label("Refresh Insights", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isLoadingInsights || isLoadingTrends)

                    Spacer(minLength: 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if insights == nil {
                    loadInsights()
                }
                if trends == nil {
                    loadTrends()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
                Button("Retry") {
                    refreshAnalytics()
                }
            } message: {
                Text(errorMessage ?? "Failed to load analytics")
            }
        }
    }

    private var filteredReceipts: [Receipt] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedTimeframe {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return allReceipts.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return allReceipts.filter { $0.date >= monthAgo }
        case .threeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
            return allReceipts.filter { $0.date >= threeMonthsAgo }
        case .sixMonths:
            let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: now)!
            return allReceipts.filter { $0.date >= sixMonthsAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return allReceipts.filter { $0.date >= yearAgo }
        }
    }

    private func loadInsights() {
        guard !allReceipts.isEmpty else {
            insights = SpendingInsights.default
            return
        }

        isLoadingInsights = true
        SpendingAnalyticsService.shared.generateSpendingInsights(
            receipts: Array(allReceipts.prefix(100)),
            budgets: budgets
        ) { result in
            DispatchQueue.main.async {
                isLoadingInsights = false
                switch result {
                case .success(let data):
                    insights = data
                    HapticManager.shared.notification(.success)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                    insights = SpendingInsights.default
                }
            }
        }
    }

    private func loadTrends() {
        guard !allReceipts.isEmpty else {
            trends = TrendAnalysis.default
            return
        }

        isLoadingTrends = true
        SpendingAnalyticsService.shared.analyzeTrends(
            receipts: filteredReceipts,
            timeframe: selectedTimeframe
        ) { result in
            DispatchQueue.main.async {
                isLoadingTrends = false
                switch result {
                case .success(let data):
                    trends = data
                    HapticManager.shared.notification(.success)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                    trends = TrendAnalysis.default
                }
            }
        }
    }

    private func refreshAnalytics() {
        loadInsights()
        loadTrends()
        HapticManager.shared.impact(.medium)
    }
}

// MARK: - Insights Section
struct InsightsSection: View {
    let insights: SpendingInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Insights")
                .font(.title3)
                .bold()
                .padding(.horizontal)

            // Summary Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("Summary")
                        .font(.headline)
                }

                Text(insights.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .cardShadow()
            .padding(.horizontal)

            // Top Categories
            if !insights.topCategories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .foregroundStyle(.orange)
                        Text("Top Spending Categories")
                            .font(.headline)
                    }

                    HStack(spacing: 8) {
                        ForEach(insights.topCategories, id: \.self) { category in
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .cardShadow()
                .padding(.horizontal)
            }

            // Individual Insights
            if !insights.insights.isEmpty {
                ForEach(insights.insights.indices, id: \.self) { index in
                    InsightCard(insight: insights.insights[index])
                        .padding(.horizontal)
                }
            }

            // Prediction
            if let prediction = insights.prediction {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "crystal.ball.fill")
                            .foregroundStyle(.blue)
                        Text("Next Month Prediction")
                            .font(.headline)
                    }

                    Text("$\(prediction.nextMonthEstimate, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(prediction.reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .cardShadow()
                .padding(.horizontal)
            }

            // Recommendations
            if !insights.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text("Recommendations")
                            .font(.headline)
                    }

                    ForEach(insights.recommendations.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(insights.recommendations[index])
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .cardShadow()
                .padding(.horizontal)
            }

            // Anomalies
            if !insights.anomalies.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Unusual Activity")
                            .font(.headline)
                    }

                    ForEach(insights.anomalies.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.red)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(insights.anomalies[index].category)
                                    .font(.caption)
                                    .bold()
                                Text(insights.anomalies[index].description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(12)
                .cardShadow()
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Insight Card
struct InsightCard: View {
    let insight: Insight

    private var iconAndColor: (String, Color) {
        switch insight.type {
        case "warning":
            return ("exclamationmark.triangle.fill", .orange)
        case "success":
            return ("checkmark.circle.fill", .green)
        default:
            return ("lightbulb.fill", .blue)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconAndColor.0)
                .foregroundStyle(iconAndColor.1)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.category)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(iconAndColor.1)

                Text(insight.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding()
        .background(iconAndColor.1.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Trends Section
struct TrendsSection: View {
    let trends: TrendAnalysis

    private var trendColor: Color {
        switch trends.trend {
        case "increasing":
            return .red
        case "decreasing":
            return .green
        default:
            return .blue
        }
    }

    private var trendIcon: String {
        switch trends.trend {
        case "increasing":
            return "arrow.up.right"
        case "decreasing":
            return "arrow.down.right"
        default:
            return "arrow.right"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trend Analysis")
                .font(.title3)
                .bold()
                .padding(.horizontal)

            // Overall Trend
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(trendColor)
                    Text("Overall Trend")
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                        Text("\(abs(trends.percentageChange), specifier: "%.1f")%")
                    }
                    .font(.title3)
                    .bold()
                    .foregroundStyle(trendColor)
                }

                Text(trends.analysis)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .cardShadow()
            .padding(.horizontal)

            // Category Trends
            if !trends.categoryTrends.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category Breakdown")
                        .font(.headline)

                    ForEach(trends.categoryTrends.indices, id: \.self) { index in
                        CategoryTrendRow(trend: trends.categoryTrends[index])
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .cardShadow()
                .padding(.horizontal)
            }

            // Weekday Pattern
            if !trends.weekdayPattern.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.purple)
                        Text("Spending Pattern")
                            .font(.headline)
                    }

                    Text(trends.weekdayPattern)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .cardShadow()
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Category Trend Row
struct CategoryTrendRow: View {
    let trend: CategoryTrend

    private var trendColor: Color {
        switch trend.trend {
        case "up":
            return .red
        case "down":
            return .green
        default:
            return .gray
        }
    }

    private var trendIcon: String {
        switch trend.trend {
        case "up":
            return "arrow.up"
        case "down":
            return "arrow.down"
        default:
            return "arrow.left.arrow.right"
        }
    }

    var body: some View {
        HStack {
            Text(trend.category)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                Text("\(abs(trend.change), specifier: "%.1f")%")
            }
            .font(.caption)
            .bold()
            .foregroundStyle(trendColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Spending Chart View
struct SpendingChartView: View {
    let receipts: [Receipt]

    private var chartData: [(Date, Double)] {
        let calendar = Calendar.current
        var dailySpending: [Date: Double] = [:]

        for receipt in receipts {
            let startOfDay = calendar.startOfDay(for: receipt.date)
            dailySpending[startOfDay, default: 0] += receipt.totalAmount
        }

        return dailySpending.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Over Time")
                .font(.headline)

            if chartData.isEmpty {
                Text("No data to display")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(chartData, id: \.0) { date, amount in
                        LineMark(
                            x: .value("Date", date),
                            y: .value("Amount", amount)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", date),
                            y: .value("Amount", amount)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxisLabel("Amount ($)")
                .chartXAxisLabel("Date")
            }
        }
    }
}
