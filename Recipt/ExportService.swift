import Foundation
import UIKit
import PDFKit

// MARK: - Export Service
class ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - Export to CSV
    func exportToCSV(receipts: [Receipt]) -> URL? {
        var csvString = "Date,Store,Category,Total,Items\n"

        for receipt in receipts {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short

            let dateString = dateFormatter.string(from: receipt.date)
            let store = receipt.storeName.replacingOccurrences(of: ",", with: ";")
            let category = receipt.category.rawValue
            let total = String(format: "%.2f", receipt.totalAmount)
            let items = receipt.items.map { $0.name }.joined(separator: "; ")

            csvString += "\(dateString),\(store),\(category),\(total),\"\(items)\"\n"
        }

        // Save to temporary file
        let fileName = "receipts_\(Date().timeIntervalSince1970).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Error writing CSV: \(error)")
            return nil
        }
    }

    // MARK: - Export to PDF
    func exportToPDF(receipts: [Receipt]) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Receipt Tracker",
            kCGPDFContextTitle: "Receipt Export"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let fileName = "receipts_\(Date().timeIntervalSince1970).pdf"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        do {
            try renderer.writePDF(to: path) { context in
                var currentY: CGFloat = 50
                let margin: CGFloat = 50
                let contentWidth = pageWidth - (2 * margin)

                for (index, receipt) in receipts.enumerated() {
                    // Check if we need a new page
                    if currentY > pageHeight - 200 {
                        context.beginPage()
                        currentY = 50
                    }

                    // Draw receipt
                    currentY = drawReceipt(
                        receipt: receipt,
                        context: context.cgContext,
                        startY: currentY,
                        margin: margin,
                        contentWidth: contentWidth,
                        index: index
                    )

                    currentY += 30 // Space between receipts
                }
            }

            return path
        } catch {
            print("Error creating PDF: \(error)")
            return nil
        }
    }

    // MARK: - Helper Methods
    private func drawReceipt(
        receipt: Receipt,
        context: CGContext,
        startY: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        index: Int
    ) -> CGFloat {
        var yPosition = startY

        // Receipt number
        let numberText = "Receipt #\(index + 1)"
        numberText.draw(
            at: CGPoint(x: margin, y: yPosition),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.systemGray
            ]
        )
        yPosition += 25

        // Store name
        receipt.storeName.draw(
            at: CGPoint(x: margin, y: yPosition),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
        )
        yPosition += 25

        // Date and category
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: receipt.date)

        let detailsText = "\(dateString) • \(receipt.category.rawValue)"
        detailsText.draw(
            at: CGPoint(x: margin, y: yPosition),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.systemGray
            ]
        )
        yPosition += 25

        // Divider
        context.setStrokeColor(UIColor.systemGray5.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: yPosition))
        context.strokePath()
        yPosition += 15

        // Items
        if !receipt.items.isEmpty {
            "Items:".draw(
                at: CGPoint(x: margin, y: yPosition),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.black
                ]
            )
            yPosition += 20

            for item in receipt.items {
                let itemText = "• \(item.name)"
                let priceText = "$\(String(format: "%.2f", item.price))"

                itemText.draw(
                    at: CGPoint(x: margin + 10, y: yPosition),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor.black
                    ]
                )

                let priceSize = priceText.size(withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11)
                ])
                priceText.draw(
                    at: CGPoint(x: margin + contentWidth - priceSize.width, y: yPosition),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor.systemGray
                    ]
                )

                yPosition += 18
            }

            yPosition += 10
        }

        // Total
        context.setStrokeColor(UIColor.systemGray4.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: yPosition))
        context.strokePath()
        yPosition += 15

        let totalLabel = "Total:"
        let totalAmount = "$\(String(format: "%.2f", receipt.totalAmount))"

        totalLabel.draw(
            at: CGPoint(x: margin, y: yPosition),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
        )

        let totalSize = totalAmount.size(withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 14)
        ])
        totalAmount.draw(
            at: CGPoint(x: margin + contentWidth - totalSize.width, y: yPosition),
            withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
        )
        yPosition += 25

        // Bottom border
        context.setStrokeColor(UIColor.systemGray5.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: yPosition))
        context.strokePath()

        return yPosition
    }

    // MARK: - Export Summary Report
    func exportSummaryPDF(receipts: [Receipt], budgets: [Budget]) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Receipt Tracker",
            kCGPDFContextTitle: "Spending Summary"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let fileName = "summary_\(Date().timeIntervalSince1970).pdf"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        do {
            try renderer.writePDF(to: path) { context in
                context.beginPage()

                let margin: CGFloat = 50
                var yPosition: CGFloat = 50

                // Title
                "Spending Summary".draw(
                    at: CGPoint(x: margin, y: yPosition),
                    withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.black
                    ]
                )
                yPosition += 40

                // Date range
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium

                if let firstReceipt = receipts.last, let lastReceipt = receipts.first {
                    let dateRange = "\(dateFormatter.string(from: firstReceipt.date)) - \(dateFormatter.string(from: lastReceipt.date))"
                    dateRange.draw(
                        at: CGPoint(x: margin, y: yPosition),
                        withAttributes: [
                            .font: UIFont.systemFont(ofSize: 14),
                            .foregroundColor: UIColor.systemGray
                        ]
                    )
                    yPosition += 30
                }

                // Total spending
                let totalSpending = receipts.reduce(0) { $0 + $1.totalAmount }
                "Total Spending: $\(String(format: "%.2f", totalSpending))".draw(
                    at: CGPoint(x: margin, y: yPosition),
                    withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 18),
                        .foregroundColor: UIColor.black
                    ]
                )
                yPosition += 25

                "Total Receipts: \(receipts.count)".draw(
                    at: CGPoint(x: margin, y: yPosition),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 14),
                        .foregroundColor: UIColor.systemGray
                    ]
                )
                yPosition += 40

                // Category breakdown
                "Spending by Category".draw(
                    at: CGPoint(x: margin, y: yPosition),
                    withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 16),
                        .foregroundColor: UIColor.black
                    ]
                )
                yPosition += 25

                var categoryTotals: [Category: Double] = [:]
                for receipt in receipts {
                    categoryTotals[receipt.category, default: 0] += receipt.totalAmount
                }

                for category in Category.allCases {
                    if let amount = categoryTotals[category], amount > 0 {
                        let categoryText = category.rawValue
                        let amountText = "$\(String(format: "%.2f", amount))"

                        categoryText.draw(
                            at: CGPoint(x: margin + 10, y: yPosition),
                            withAttributes: [
                                .font: UIFont.systemFont(ofSize: 13),
                                .foregroundColor: UIColor.black
                            ]
                        )

                        let amountSize = amountText.size(withAttributes: [
                            .font: UIFont.systemFont(ofSize: 13)
                        ])
                        amountText.draw(
                            at: CGPoint(x: pageWidth - margin - amountSize.width, y: yPosition),
                            withAttributes: [
                                .font: UIFont.systemFont(ofSize: 13),
                                .foregroundColor: UIColor.systemGray
                            ]
                        )

                        yPosition += 22
                    }
                }
            }

            return path
        } catch {
            print("Error creating summary PDF: \(error)")
            return nil
        }
    }
}
