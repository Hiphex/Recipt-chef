import SwiftUI
import SwiftData

// MARK: - Receipt List View
struct ReceiptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]
    @State private var showingScanner = false
    @State private var showingBudgets = false

    var body: some View {
        NavigationStack {
            List {
                if receipts.isEmpty {
                    ContentUnavailableView(
                        "No Receipts",
                        systemImage: "receipt",
                        description: Text("Tap + to scan your first receipt")
                    )
                } else {
                    ForEach(receipts) { receipt in
                        NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                            ReceiptRow(receipt: receipt)
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingBudgets = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScanReceiptView()
            }
            .sheet(isPresented: $showingBudgets) {
                BudgetView()
            }
        }
    }

    private func deleteReceipts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(receipts[index])
        }
    }
}

// MARK: - Receipt Row
struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack {
            Image(systemName: receipt.category.icon)
                .foregroundStyle(categoryColor(receipt.category.color))
                .font(.title2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName)
                    .font(.headline)

                Text(receipt.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("$\(receipt.totalAmount, specifier: "%.2f")")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
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

// MARK: - Receipt Detail View
struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Receipt Image
                if let imageData = receipt.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                }

                // Store Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(receipt.storeName)
                        .font(.title2)
                        .bold()

                    HStack {
                        Image(systemName: receipt.category.icon)
                        Text(receipt.category.rawValue)
                    }
                    .foregroundStyle(.secondary)

                    Text(receipt.date, style: .date)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Items
                VStack(alignment: .leading, spacing: 12) {
                    Text("Items")
                        .font(.headline)

                    if receipt.items.isEmpty {
                        Text("No items detected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(receipt.items) { item in
                            HStack {
                                Text(item.name)
                                Spacer()
                                Text("$\(item.price, specifier: "%.2f")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Divider()

                // Total
                HStack {
                    Text("Total")
                        .font(.title3)
                        .bold()
                    Spacer()
                    Text("$\(receipt.totalAmount, specifier: "%.2f")")
                        .font(.title2)
                        .bold()
                }

                // Category Picker
                Picker("Category", selection: $receipt.category) {
                    ForEach(Category.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Scan Receipt View
struct ScanReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var scannedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    ProgressView("Processing receipt...")
                        .padding()
                } else {
                    Button {
                        showingCamera = true
                    } label: {
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                            Text("Scan Receipt")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("New Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                DocumentCameraView { image in
                    scannedImage = image
                    processReceipt(image: image)
                }
            }
        }
    }

    private func processReceipt(image: UIImage) {
        isProcessing = true

        ReceiptScannerService.shared.recognizeText(from: image) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    let parsedData = ReceiptScannerService.shared.parseReceipt(from: text)
                    let category = ReceiptScannerService.shared.categorizeReceipt(
                        storeName: parsedData.storeName,
                        items: parsedData.items
                    )

                    let receipt = Receipt(
                        date: parsedData.date,
                        storeName: parsedData.storeName,
                        totalAmount: parsedData.total,
                        category: category,
                        imageData: image.jpegData(compressionQuality: 0.7),
                        items: parsedData.items,
                        rawText: text
                    )

                    modelContext.insert(receipt)
                    try? modelContext.save()

                    isProcessing = false
                    dismiss()

                case .failure(let error):
                    print("Error: \(error)")
                    isProcessing = false
                }
            }
        }
    }
}
