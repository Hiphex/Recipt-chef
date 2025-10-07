import Foundation
import UIKit

// MARK: - OpenAI Receipt Scanner
class OpenAIReceiptScanner {
    static let shared = OpenAIReceiptScanner()

    private let apiKey = "" // Add your API key here
    private let apiURL = "https://api.openai.com/v1/chat/completions"

    private init() {}

    func scanReceipt(image: UIImage, completion: @escaping (Result<ParsedReceiptData, Error>) -> Void) {
        print(String(repeating: "=", count: 80))
        print("🤖 OPENAI SCANNER STARTED")
        print("API Key present: \(!apiKey.isEmpty)")
        print("Image size: \(image.size)")
        print(String(repeating: "=", count: 80))

        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            print("❌ Failed to convert image to JPEG")
            completion(.failure(ScanError.invalidImage))
            return
        }

        print("✅ Image converted to JPEG: \(imageData.count) bytes")
        let base64Image = imageData.base64EncodedString()
        print("✅ Base64 encoded: \(base64Image.count) characters")

        // Concise prompt
        let prompt = """
        Extract receipt data. CRITICAL: storeName must be the actual business name ONLY (e.g., "Walmart", "Target", "CVS"), NOT slogans or taglines like "Save money. Live better."

        Extract: storeName (business name ONLY, ignore any slogans), date (MM/DD/YYYY with 4-digit year), all items with prices, total.
        Format: {"storeName":"","date":"MM/DD/YYYY","items":[{"name":"","price":0.0}],"total":0.0}

        Examples:
        - "WALMART Save money" → storeName: "Walmart"
        - "Target Expect More" → storeName: "Target"
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

        print("🌐 Sending request to OpenAI...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print(String(repeating: "=", count: 80))
                print("❌ NETWORK ERROR")
                print("Error: \(error)")
                print(String(repeating: "=", count: 80))
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Response: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ No data received from API")
                completion(.failure(ScanError.noDataReceived))
                return
            }

            print("✅ Received \(data.count) bytes of data")

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ JSON parsed successfully")

                    // Check for API errors
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        print(String(repeating: "=", count: 80))
                        print("❌ OPENAI API ERROR")
                        print("Message: \(message)")
                        print(String(repeating: "=", count: 80))
                        completion(.failure(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: message])))
                        return
                    }

                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {

                        print("✅ Got AI response content (\(content.count) chars)")
                        print("Content preview: \(String(content.prefix(200)))")

                        // Parse the JSON response
                        let parsedData = self.parseAIResponse(content)
                        print("✅ Parsed AI response successfully")
                        completion(.success(parsedData))
                    } else {
                        print("❌ Invalid response structure from API")
                        print("JSON keys: \(json.keys)")
                        completion(.failure(ScanError.invalidResponse))
                    }
                } else {
                    print("❌ Failed to parse JSON response")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Raw response: \(responseString.prefix(500))")
                    }
                    completion(.failure(ScanError.invalidResponse))
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
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
