import Foundation
import UIKit

// MARK: - Spending Analytics Service
class SpendingAnalyticsService {
    static let shared = SpendingAnalyticsService()

    private let apiKey = "" // Add your OpenAI API key here
    private let apiURL = "https://api.openai.com/v1/chat/completions"

    private init() {}

    // MARK: - Generate Spending Insights
    func generateSpendingInsights(
        receipts: [Receipt],
        budgets: [Budget],
        completion: @escaping (Result<SpendingInsights, Error>) -> Void
    ) {
        let spendingData = prepareSpendingData(receipts: receipts, budgets: budgets)

        let prompt = """
        Analyze this spending data and provide insights in JSON format:

        \(spendingData)

        Return ONLY valid JSON with this structure:
        {
            "summary": "Brief 2-3 sentence overview of spending patterns",
            "topCategories": ["category1", "category2", "category3"],
            "insights": [
                {"type": "warning|tip|success", "category": "category", "message": "insight message"}
            ],
            "predictions": {
                "nextMonthEstimate": 0.0,
                "reasoning": "why this prediction"
            },
            "recommendations": [
                "actionable recommendation 1",
                "actionable recommendation 2"
            ],
            "anomalies": [
                {"category": "category", "description": "unusual pattern"}
            ]
        }
        """

        let requestBody: [String: Any] = [
            "model": "gpt-5-nano",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a financial analyst AI. Analyze spending patterns and provide actionable insights. Return only valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_completion_tokens": 2000,
            "reasoning_effort": "medium"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(AnalyticsError.invalidRequest))
            return
        }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(AnalyticsError.noDataReceived))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for API errors
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: message])))
                        return
                    }

                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {

                        let insights = self.parseInsightsResponse(content)
                        completion(.success(insights))
                    } else {
                        completion(.failure(AnalyticsError.invalidResponse))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Generate Spending Trends Analysis
    func analyzeTrends(
        receipts: [Receipt],
        timeframe: AnalyticsTimeframe,
        completion: @escaping (Result<TrendAnalysis, Error>) -> Void
    ) {
        let trendData = prepareTrendData(receipts: receipts, timeframe: timeframe)

        let prompt = """
        Analyze these spending trends over time and provide analysis in JSON:

        \(trendData)

        Return ONLY valid JSON:
        {
            "trend": "increasing|decreasing|stable",
            "percentageChange": 0.0,
            "analysis": "2-3 sentence trend analysis",
            "categoryTrends": [
                {"category": "name", "trend": "up|down|stable", "change": 0.0}
            ],
            "weekdayPattern": "spending pattern by day of week",
            "recommendations": ["suggestion 1", "suggestion 2"]
        }
        """

        let requestBody: [String: Any] = [
            "model": "gpt-5-nano",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a financial trend analyst. Analyze spending patterns over time. Return only valid JSON."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_completion_tokens": 1500,
            "reasoning_effort": "medium"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(AnalyticsError.invalidRequest))
            return
        }

        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(AnalyticsError.noDataReceived))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        completion(.failure(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: message])))
                        return
                    }

                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {

                        let trends = self.parseTrendResponse(content)
                        completion(.success(trends))
                    } else {
                        completion(.failure(AnalyticsError.invalidResponse))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Helper Methods
    private func prepareSpendingData(receipts: [Receipt], budgets: [Budget]) -> String {
        var data = "Current Month Spending:\n"

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Filter current month receipts
        let monthReceipts = receipts.filter { receipt in
            calendar.component(.month, from: receipt.date) == currentMonth &&
            calendar.component(.year, from: receipt.date) == currentYear
        }

        // Group by category
        var categorySpending: [Category: Double] = [:]
        for receipt in monthReceipts {
            categorySpending[receipt.category, default: 0] += receipt.totalAmount
        }

        // Add spending by category
        for category in Category.allCases {
            let spent = categorySpending[category] ?? 0
            let budget = budgets.first { $0.category == category }
            let limit = budget?.monthlyLimit ?? 0

            if spent > 0 || limit > 0 {
                data += "- \(category.rawValue): $\(String(format: "%.2f", spent))"
                if limit > 0 {
                    data += " / $\(String(format: "%.2f", limit)) budget"
                }
                data += "\n"
            }
        }

        data += "\nTotal Spending: $\(String(format: "%.2f", monthReceipts.reduce(0) { $0 + $1.totalAmount }))\n"
        data += "Number of Transactions: \(monthReceipts.count)\n"

        // Add recent stores
        let recentStores = Set(monthReceipts.prefix(10).map { $0.storeName })
        if !recentStores.isEmpty {
            data += "Recent Stores: \(recentStores.joined(separator: ", "))\n"
        }

        return data
    }

    private func prepareTrendData(receipts: [Receipt], timeframe: AnalyticsTimeframe) -> String {
        var data = "Spending Over Time:\n"

        let calendar = Calendar.current

        // Group receipts by period
        var periodSpending: [String: Double] = [:]

        for receipt in receipts {
            let period: String
            switch timeframe {
            case .week:
                let weekOfYear = calendar.component(.weekOfYear, from: receipt.date)
                let year = calendar.component(.year, from: receipt.date)
                period = "Week \(weekOfYear), \(year)"
            case .month:
                let month = calendar.component(.month, from: receipt.date)
                let year = calendar.component(.year, from: receipt.date)
                period = "\(calendar.monthSymbols[month - 1]) \(year)"
            case .threeMonths, .sixMonths, .year:
                let month = calendar.component(.month, from: receipt.date)
                let year = calendar.component(.year, from: receipt.date)
                period = "\(calendar.monthSymbols[month - 1]) \(year)"
            }

            periodSpending[period, default: 0] += receipt.totalAmount
        }

        // Sort and format
        for (period, amount) in periodSpending.sorted(by: { $0.key < $1.key }) {
            data += "- \(period): $\(String(format: "%.2f", amount))\n"
        }

        return data
    }

    private func parseInsightsResponse(_ jsonString: String) -> SpendingInsights {
        var cleanJSON = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks
        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
            cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
            cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract JSON
        if let startIndex = cleanJSON.firstIndex(of: "{"),
           let endIndex = cleanJSON.lastIndex(of: "}") {
            cleanJSON = String(cleanJSON[startIndex...endIndex])
        }

        guard let jsonData = cleanJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return SpendingInsights.default
        }

        let summary = json["summary"] as? String ?? "No insights available"
        let topCategories = json["topCategories"] as? [String] ?? []

        var insights: [Insight] = []
        if let insightsArray = json["insights"] as? [[String: Any]] {
            for item in insightsArray {
                let type = item["type"] as? String ?? "tip"
                let category = item["category"] as? String ?? ""
                let message = item["message"] as? String ?? ""
                insights.append(Insight(type: type, category: category, message: message))
            }
        }

        var prediction: Prediction? = nil
        if let predDict = json["predictions"] as? [String: Any] {
            let estimate = predDict["nextMonthEstimate"] as? Double ?? 0
            let reasoning = predDict["reasoning"] as? String ?? ""
            prediction = Prediction(nextMonthEstimate: estimate, reasoning: reasoning)
        }

        let recommendations = json["recommendations"] as? [String] ?? []

        var anomalies: [Anomaly] = []
        if let anomaliesArray = json["anomalies"] as? [[String: Any]] {
            for item in anomaliesArray {
                let category = item["category"] as? String ?? ""
                let description = item["description"] as? String ?? ""
                anomalies.append(Anomaly(category: category, description: description))
            }
        }

        return SpendingInsights(
            summary: summary,
            topCategories: topCategories,
            insights: insights,
            prediction: prediction,
            recommendations: recommendations,
            anomalies: anomalies
        )
    }

    private func parseTrendResponse(_ jsonString: String) -> TrendAnalysis {
        var cleanJSON = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
            cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
            cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let startIndex = cleanJSON.firstIndex(of: "{"),
           let endIndex = cleanJSON.lastIndex(of: "}") {
            cleanJSON = String(cleanJSON[startIndex...endIndex])
        }

        guard let jsonData = cleanJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return TrendAnalysis.default
        }

        let trend = json["trend"] as? String ?? "stable"
        let percentageChange = json["percentageChange"] as? Double ?? 0
        let analysis = json["analysis"] as? String ?? "No trend analysis available"

        var categoryTrends: [CategoryTrend] = []
        if let trendsArray = json["categoryTrends"] as? [[String: Any]] {
            for item in trendsArray {
                let category = item["category"] as? String ?? ""
                let trendDir = item["trend"] as? String ?? "stable"
                let change = item["change"] as? Double ?? 0
                categoryTrends.append(CategoryTrend(category: category, trend: trendDir, change: change))
            }
        }

        let weekdayPattern = json["weekdayPattern"] as? String ?? ""
        let recommendations = json["recommendations"] as? [String] ?? []

        return TrendAnalysis(
            trend: trend,
            percentageChange: percentageChange,
            analysis: analysis,
            categoryTrends: categoryTrends,
            weekdayPattern: weekdayPattern,
            recommendations: recommendations
        )
    }
}

// MARK: - Data Models
struct SpendingInsights {
    let summary: String
    let topCategories: [String]
    let insights: [Insight]
    let prediction: Prediction?
    let recommendations: [String]
    let anomalies: [Anomaly]

    static let `default` = SpendingInsights(
        summary: "Not enough data to generate insights yet.",
        topCategories: [],
        insights: [],
        prediction: nil,
        recommendations: ["Start adding receipts to get personalized insights!"],
        anomalies: []
    )
}

struct Insight {
    let type: String // "warning", "tip", "success"
    let category: String
    let message: String
}

struct Prediction {
    let nextMonthEstimate: Double
    let reasoning: String
}

struct Anomaly {
    let category: String
    let description: String
}

struct TrendAnalysis {
    let trend: String // "increasing", "decreasing", "stable"
    let percentageChange: Double
    let analysis: String
    let categoryTrends: [CategoryTrend]
    let weekdayPattern: String
    let recommendations: [String]

    static let `default` = TrendAnalysis(
        trend: "stable",
        percentageChange: 0,
        analysis: "Not enough historical data for trend analysis.",
        categoryTrends: [],
        weekdayPattern: "No pattern detected yet",
        recommendations: []
    )
}

struct CategoryTrend {
    let category: String
    let trend: String
    let change: Double
}

enum AnalyticsTimeframe {
    case week
    case month
    case threeMonths
    case sixMonths
    case year
}

// MARK: - Errors
enum AnalyticsError: LocalizedError {
    case invalidRequest
    case noDataReceived
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Failed to create analytics request"
        case .noDataReceived:
            return "No data received from analytics service"
        case .invalidResponse:
            return "Invalid response from analytics service"
        }
    }
}
