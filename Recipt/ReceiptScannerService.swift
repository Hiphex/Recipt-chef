import Vision
import UIKit
import SwiftUI

// MARK: - Receipt Scanner Service
class ReceiptScannerService {
    static let shared = ReceiptScannerService()

    private init() {}

    // MARK: - OCR Text Recognition
    func recognizeText(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ScanError.invalidImage))
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(ScanError.noTextFound))
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            completion(.success(recognizedText))
        }

        // Configure for accurate recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Parse Receipt Data
    func parseReceipt(from text: String) -> ParsedReceiptData {
        var items: [ReceiptItem] = []
        var total: Double = 0.0
        var subtotal: Double = 0.0
        var tax: Double = 0.0
        var storeName: String = ""
        var date: Date = Date()

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Extract store name (first 1-3 lines, pick the longest one that looks like a name)
        let potentialStoreNames = lines.prefix(3).filter { line in
            let lower = line.lowercased()
            return !lower.contains("receipt") &&
                   !lower.contains("store") &&
                   !lower.contains("date") &&
                   !line.contains(":") &&
                   line.count > 3
        }
        if let longestName = potentialStoreNames.max(by: { $0.count < $1.count }) {
            storeName = longestName
        } else if let firstLine = lines.first {
            storeName = firstLine
        }

        // Enhanced price patterns
        let pricePatterns = [
            #"\$\s*\d+\.\d{2}"#,           // $12.99 or $ 12.99
            #"\d+\.\d{2}"#,                // 12.99
        ]

        let datePattern = #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#

        // Keywords to exclude from items
        let excludeKeywords = [
            "subtotal", "sub total", "sub-total",
            "total", "grand total",
            "tax", "sales tax", "vat",
            "cash", "change", "paid", "payment",
            "balance", "due", "tender",
            "credit", "debit", "card",
            "visa", "mastercard", "amex",
            "thank you", "thanks"
        ]

        for line in lines {
            let lowercaseLine = line.lowercased()

            // Extract date
            if let dateMatch = line.range(of: datePattern, options: .regularExpression) {
                let dateString = String(line[dateMatch])
                if let parsedDate = parseDate(from: dateString) {
                    date = parsedDate
                }
            }

            // Find all prices in the line
            var allPricesInLine: [Double] = []
            for pattern in pricePatterns {
                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                let nsString = line as NSString
                let matches = regex?.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []

                for match in matches {
                    let priceString = nsString.substring(with: match.range)
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: " ", with: "")
                    if let price = Double(priceString), price > 0 {
                        allPricesInLine.append(price)
                    }
                }
            }

            guard !allPricesInLine.isEmpty else { continue }

            // Take the last price on the line (usually the total for that item)
            guard let price = allPricesInLine.last else { continue }

            // Check if this is a special line (total, tax, etc.)
            let isExcluded = excludeKeywords.contains { keyword in
                lowercaseLine.contains(keyword)
            }

            if lowercaseLine.contains("total") && !lowercaseLine.contains("subtotal") {
                total = price
            } else if lowercaseLine.contains("subtotal") || lowercaseLine.contains("sub total") {
                subtotal = price
            } else if lowercaseLine.contains("tax") {
                tax = price
            } else if !isExcluded {
                // This is likely an item
                // Extract item name (everything before the price)
                var itemName = line

                // Remove all prices from the line to get the item name
                for pattern in pricePatterns {
                    itemName = itemName.replacingOccurrences(
                        of: pattern,
                        with: "",
                        options: .regularExpression
                    )
                }

                // Clean up the item name
                itemName = itemName
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression) // Multiple spaces to single
                    .replacingOccurrences(of: #"^\d+\s*x\s*"#, with: "", options: [.regularExpression, .caseInsensitive]) // Remove "2 x" quantity
                    .replacingOccurrences(of: #"^\d+\s+"#, with: "", options: .regularExpression) // Remove leading numbers

                // Only add if we have a reasonable item name
                if !itemName.isEmpty && itemName.count > 1 {
                    let item = ReceiptItem(name: itemName, price: price)
                    items.append(item)
                }
            }
        }

        // Calculate total if not found
        if total == 0.0 {
            if subtotal > 0 && tax > 0 {
                total = subtotal + tax
            } else if !items.isEmpty {
                total = items.reduce(0.0) { $0 + $1.price }
                if tax > 0 {
                    total += tax
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

    // MARK: - Auto-categorize Receipt
    func categorizeReceipt(storeName: String, items: [ReceiptItem]) -> Category {
        let name = storeName.lowercased()

        // Store name keywords
        if name.contains("grocery") || name.contains("market") || name.contains("whole foods") ||
           name.contains("trader joe") || name.contains("safeway") || name.contains("walmart") {
            return .groceries
        }

        if name.contains("restaurant") || name.contains("cafe") || name.contains("coffee") ||
           name.contains("pizza") || name.contains("burger") || name.contains("starbucks") {
            return .dining
        }

        if name.contains("gas") || name.contains("shell") || name.contains("chevron") ||
           name.contains("uber") || name.contains("lyft") {
            return .transport
        }

        if name.contains("movie") || name.contains("theater") || name.contains("cinema") {
            return .entertainment
        }

        if name.contains("pharmacy") || name.contains("cvs") || name.contains("walgreens") ||
           name.contains("hospital") || name.contains("clinic") {
            return .health
        }

        // Check items for additional context
        let itemNames = items.map { $0.name.lowercased() }.joined(separator: " ")
        if itemNames.contains("milk") || itemNames.contains("bread") || itemNames.contains("eggs") {
            return .groceries
        }

        return .other
    }

    // MARK: - Helper Methods
    private func parseDate(from string: String) -> Date? {
        let formatters = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "MM/dd/yy",
            "MM-dd-yy",
            "M/d/yyyy",
            "M-d-yyyy",
            "M/d/yy",
            "M-d-yy"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format

            // Handle 2-digit years properly (interpret as 20xx, not 00xx)
            if format.contains("yy") && !format.contains("yyyy") {
                // Set the century to start at 1950, so 00-49 -> 2000-2049, 50-99 -> 1950-1999
                let calendar = Calendar.current
                if let startDate = calendar.date(from: DateComponents(year: 1950)) {
                    formatter.twoDigitStartDate = startDate
                }
            }

            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }
}

// MARK: - Supporting Types
struct ParsedReceiptData {
    var storeName: String
    var date: Date
    var items: [ReceiptItem]
    var total: Double
}

enum ScanError: LocalizedError {
    case invalidImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided"
        case .noTextFound:
            return "No text found in image"
        }
    }
}
