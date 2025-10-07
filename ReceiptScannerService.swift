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
        var storeName: String = ""
        var date: Date = Date()

        let lines = text.components(separatedBy: .newlines)

        // Extract store name (usually first non-empty line)
        if let firstLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            storeName = firstLine.trimmingCharacters(in: .whitespaces)
        }

        // Regular expressions for parsing
        let pricePattern = #"\$?\d+\.\d{2}"#
        let datePattern = #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#

        for line in lines {
            // Extract date
            if let dateMatch = line.range(of: datePattern, options: .regularExpression) {
                let dateString = String(line[dateMatch])
                if let parsedDate = parseDate(from: dateString) {
                    date = parsedDate
                }
            }

            // Extract items and prices
            if let priceMatch = line.range(of: pricePattern, options: .regularExpression) {
                let priceString = String(line[priceMatch]).replacingOccurrences(of: "$", with: "")
                if let price = Double(priceString) {
                    // Check if this line contains "total", "subtotal", etc.
                    let lowercaseLine = line.lowercased()
                    if lowercaseLine.contains("total") && !lowercaseLine.contains("subtotal") {
                        total = price
                    } else if !lowercaseLine.contains("tax") &&
                              !lowercaseLine.contains("subtotal") &&
                              !lowercaseLine.contains("change") {
                        // Extract item name (everything before the price)
                        var itemName = line
                        if let range = itemName.range(of: pricePattern, options: .regularExpression) {
                            itemName = String(itemName[..<range.lowerBound])
                        }
                        itemName = itemName.trimmingCharacters(in: .whitespaces)

                        if !itemName.isEmpty {
                            let item = ReceiptItem(name: itemName, price: price)
                            items.append(item)
                        }
                    }
                }
            }
        }

        // If no total found, sum up all items
        if total == 0.0 {
            total = items.reduce(0.0) { $0 + $1.price }
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
            "M-d-yyyy"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
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
