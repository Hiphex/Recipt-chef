import Foundation
import UIKit

// MARK: - OpenAI Receipt Scanner
class OpenAIReceiptScanner {
    static let shared = OpenAIReceiptScanner()

    private let apiKey = "" // Add your API key here
    private let apiURL = "https://api.openai.com/v1/chat/completions"

    private init() {}

    func scanReceipt(image: UIImage, completion: @escaping (Result<ParsedReceiptData, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            completion(.failure(ScanError.invalidImage))
            return
        }

        let base64Image = imageData.base64EncodedString()

        // Concise prompt
        let prompt = """
        Extract: storeName (not slogan), date (MM/DD/2024 or MM/DD/2025 - use 4 digits), all items with prices, total.
        Format: {"storeName":"","date":"MM/DD/YYYY","items":[{"name":"","price":0.0}],"total":0.0}
        """

        let requestBody: [String: Any] = [
            "model": "gpt-5-nano",
            "messages": [
                [
                    "role": "system",
                    "content": "You extract receipt data. Return only valid JSON, no explanations."
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "low"
                            ]
                        ]
                    ]
                ]
            ],
            "max_completion_tokens": 1000,
            "reasoning_effort": "minimal"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(ScanError.invalidRequest))
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
                completion(.failure(ScanError.noDataReceived))
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

                        // Parse the JSON response
                        let parsedData = self.parseAIResponse(content)
                        completion(.success(parsedData))
                    } else {
                        completion(.failure(ScanError.invalidResponse))
                    }
                } else {
                    completion(.failure(ScanError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func parseAIResponse(_ jsonString: String) -> ParsedReceiptData {
        // Extract JSON from markdown code blocks if present
        var cleanJSON = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if cleanJSON.hasPrefix("```") {
            cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
            cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
            cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find first { and last }
        if let startIndex = cleanJSON.firstIndex(of: "{"),
           let endIndex = cleanJSON.lastIndex(of: "}") {
            cleanJSON = String(cleanJSON[startIndex...endIndex])
        }

        guard let jsonData = cleanJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return ParsedReceiptData(
                storeName: "Unknown Store",
                date: Date(),
                items: [],
                total: 0.0
            )
        }

        let storeName = json["storeName"] as? String ?? "Unknown Store"
        let total = json["total"] as? Double ?? 0.0

        // Parse date
        var date = Date()
        if let dateString = json["date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yyyy"
            if let parsedDate = formatter.date(from: dateString) {
                // If date is too old or in the future, use today's date
                let yearsDiff = Calendar.current.dateComponents([.year], from: parsedDate, to: Date()).year ?? 0
                let monthsDiff = Calendar.current.dateComponents([.month], from: parsedDate, to: Date()).month ?? 0

                if abs(yearsDiff) > 2 || abs(monthsDiff) > 1 {
                    // Receipt is old or date parsing failed - use today's date
                    date = Date()
                } else {
                    date = parsedDate
                }
            }
        }

        // Parse items
        var items: [ReceiptItem] = []
        if let itemsArray = json["items"] as? [[String: Any]] {
            for itemDict in itemsArray {
                if let name = itemDict["name"] as? String,
                   let price = itemDict["price"] as? Double {
                    items.append(ReceiptItem(name: name, price: price))
                }
            }
        }

        return ParsedReceiptData(
            storeName: storeName,
            date: date,
            items: items,
            total: total
        )
    }
}

// MARK: - Errors
enum OpenAIScanError: LocalizedError {
    case invalidRequest
    case noDataReceived
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Failed to create API request"
        case .noDataReceived:
            return "No data received from API"
        case .invalidResponse:
            return "Invalid response from API"
        }
    }
}

extension ScanError {
    static let invalidRequest = OpenAIScanError.invalidRequest
    static let noDataReceived = OpenAIScanError.noDataReceived
    static let invalidResponse = OpenAIScanError.invalidResponse
}
