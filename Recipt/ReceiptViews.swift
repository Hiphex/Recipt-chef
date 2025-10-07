import SwiftUI
import SwiftData

// MARK: - Receipt List View
struct ReceiptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]
    @State private var showingScanner = false
    @State private var showingBudgets = false
    @State private var searchText = ""
    @State private var selectedCategory: Category? = nil
    @State private var showingFilters = false
    @State private var showingExportSheet = false
    @State private var showingDateFilter = false
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil
    @State private var selectedTag: String? = nil

    private var allTags: [String] {
        Array(Set(receipts.flatMap { $0.tags })).sorted()
    }

    private var filteredReceipts: [Receipt] {
        var result = receipts

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { receipt in
                receipt.storeName.localizedCaseInsensitiveContains(searchText) ||
                receipt.items.contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
                receipt.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by tag
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Filter by date range
        if let start = startDate {
            result = result.filter { $0.date >= start }
        }
        if let end = endDate {
            let calendar = Calendar.current
            if let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) {
                result = result.filter { $0.date <= endOfDay }
            }
        }

        return result
    }

    private var activeFiltersCount: Int {
        var count = 0
        if selectedCategory != nil { count += 1 }
        if selectedTag != nil { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        return count
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredReceipts.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Receipts" : "No Results",
                        systemImage: searchText.isEmpty ? "receipt" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Tap + to scan your first receipt" : "Try a different search term")
                    )
                } else {
                    ForEach(filteredReceipts) { receipt in
                        NavigationLink(destination: ReceiptDetailView(receipt: receipt)) {
                            ReceiptRow(receipt: receipt)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    modelContext.delete(receipt)
                                }
                                HapticManager.shared.notification(.success)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search receipts or items...")
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        // Category Filter
                        Menu {
                            Button {
                                selectedCategory = nil
                            } label: {
                                Label("All Categories", systemImage: selectedCategory == nil ? "checkmark" : "")
                            }

                            Divider()

                            ForEach(Category.allCases, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Label(category.rawValue, systemImage: selectedCategory == category ? "checkmark" : category.icon)
                                }
                            }
                        } label: {
                            Label("Category", systemImage: "tag")
                        }

                        // Tag Filter
                        if !allTags.isEmpty {
                            Menu {
                                Button {
                                    selectedTag = nil
                                } label: {
                                    Label("All Tags", systemImage: selectedTag == nil ? "checkmark" : "")
                                }

                                Divider()

                                ForEach(allTags, id: \.self) { tag in
                                    Button {
                                        selectedTag = tag
                                    } label: {
                                        Label(tag, systemImage: selectedTag == tag ? "checkmark" : "tag.fill")
                                    }
                                }
                            } label: {
                                Label("Tags", systemImage: "tag.fill")
                            }
                        }

                        // Date Filter
                        Button {
                            showingDateFilter = true
                        } label: {
                            Label("Date Range", systemImage: "calendar")
                        }

                        Divider()

                        // Clear Filters
                        if activeFiltersCount > 0 {
                            Button(role: .destructive) {
                                selectedCategory = nil
                                selectedTag = nil
                                startDate = nil
                                endDate = nil
                            } label: {
                                Label("Clear All Filters", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundStyle(activeFiltersCount > 0 ? Color.accentColor : Color.primary)

                            if activeFiltersCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan Receipt", systemImage: "camera")
                        }

                        Divider()

                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Export Receipts", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScanReceiptView()
            }
            .sheet(isPresented: $showingBudgets) {
                BudgetView()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheetView(receipts: filteredReceipts)
            }
            .sheet(isPresented: $showingDateFilter) {
                DateRangeFilterView(startDate: $startDate, endDate: $endDate)
            }
        }
    }
}

// MARK: - Date Range Filter View
struct DateRangeFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date?
    @Binding var endDate: Date?

    @State private var tempStartDate: Date
    @State private var tempEndDate: Date
    @State private var useStartDate: Bool
    @State private var useEndDate: Bool

    init(startDate: Binding<Date?>, endDate: Binding<Date?>) {
        self._startDate = startDate
        self._endDate = endDate
        self._tempStartDate = State(initialValue: startDate.wrappedValue ?? Date())
        self._tempEndDate = State(initialValue: endDate.wrappedValue ?? Date())
        self._useStartDate = State(initialValue: startDate.wrappedValue != nil)
        self._useEndDate = State(initialValue: endDate.wrappedValue != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Filter from date", isOn: $useStartDate)

                    if useStartDate {
                        DatePicker("Start Date", selection: $tempStartDate, displayedComponents: .date)
                    }
                }

                Section {
                    Toggle("Filter to date", isOn: $useEndDate)

                    if useEndDate {
                        DatePicker("End Date", selection: $tempEndDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Apply Filters") {
                        startDate = useStartDate ? tempStartDate : nil
                        endDate = useEndDate ? tempEndDate : nil
                        dismiss()
                    }

                    Button("Clear Filters", role: .destructive) {
                        startDate = nil
                        endDate = nil
                        useStartDate = false
                        useEndDate = false
                        dismiss()
                    }
                }
            }
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export Sheet View
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let receipts: [Receipt]

    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        exportToCSV()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("Export as CSV")
                                    .foregroundStyle(.primary)
                                Text("Spreadsheet format")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isExporting || receipts.isEmpty)

                    Button {
                        exportToPDF()
                    } label: {
                        HStack {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading) {
                                Text("Export as PDF")
                                    .foregroundStyle(.primary)
                                Text("Detailed receipt list")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isExporting || receipts.isEmpty)
                } header: {
                    Text("Export Options")
                } footer: {
                    if receipts.isEmpty {
                        Text("No receipts to export")
                    } else {
                        Text("\(receipts.count) receipt\(receipts.count == 1 ? "" : "s") will be exported")
                    }
                }

                if isExporting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Preparing export...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Export Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportToCSV() {
        isExporting = true
        HapticManager.shared.impact(.medium)

        DispatchQueue.global(qos: .userInitiated).async {
            if let url = ExportService.shared.exportToCSV(receipts: receipts) {
                DispatchQueue.main.async {
                    isExporting = false
                    exportURL = url
                    showingShareSheet = true
                    HapticManager.shared.notification(.success)
                }
            } else {
                DispatchQueue.main.async {
                    isExporting = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    private func exportToPDF() {
        isExporting = true
        HapticManager.shared.impact(.medium)

        DispatchQueue.global(qos: .userInitiated).async {
            if let url = ExportService.shared.exportToPDF(receipts: receipts) {
                DispatchQueue.main.async {
                    isExporting = false
                    exportURL = url
                    showingShareSheet = true
                    HapticManager.shared.notification(.success)
                }
            } else {
                DispatchQueue.main.async {
                    isExporting = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Receipt Row
struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            // Receipt thumbnail or placeholder
            if let imageData = receipt.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(categoryColor(receipt.category.color).opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: receipt.category.icon)
                        .foregroundStyle(categoryColor(receipt.category.color))
                        .font(.title2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.storeName)
                    .font(.headline)
                    .lineLimit(1)

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
    @State private var newTag = ""
    @State private var showingAddTag = false

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
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
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

                // Tags
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Tags")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingAddTag = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    if receipt.tags.isEmpty {
                        Text("No tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(receipt.tags, id: \.self) { tag in
                                TagView(tag: tag) {
                                    receipt.tags.removeAll { $0 == tag }
                                }
                            }
                        }
                    }
                }

                Divider()

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)

                    TextEditor(text: Binding(
                        get: { receipt.notes ?? "" },
                        set: { receipt.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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
        .alert("Add Tag", isPresented: $showingAddTag) {
            TextField("Tag name", text: $newTag)
            Button("Cancel", role: .cancel) {
                newTag = ""
            }
            Button("Add") {
                if !newTag.isEmpty && !receipt.tags.contains(newTag) {
                    receipt.tags.append(newTag)
                    newTag = ""
                }
            }
        }
    }
}

// MARK: - Tag View
struct TagView: View {
    let tag: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.15))
        .foregroundStyle(Color.accentColor)
        .cornerRadius(12)
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Scan Receipt View
struct ScanReceiptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var scannedImage: UIImage?
    @State private var parsedData: ParsedReceiptData?
    @State private var extractedText: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack {
                if isProcessing {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Scanning receipt...")
                            .font(.headline)
                        Text("Analyzing with AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if let parsedData = parsedData, let image = scannedImage {
                    ReviewReceiptView(
                        image: image,
                        parsedData: parsedData,
                        extractedText: extractedText,
                        onSave: { receipt in
                            print("📝 Attempting to save receipt: \(receipt.storeName) - $\(receipt.totalAmount)")

                            do {
                                modelContext.insert(receipt)
                                try modelContext.save()
                                print("✅ Receipt saved successfully: \(receipt.storeName)")
                                HapticManager.shared.notification(.success)
                                dismiss()
                            } catch {
                                print("❌ Failed to save receipt: \(error.localizedDescription)")
                                errorMessage = "Failed to save receipt: \(error.localizedDescription)"
                                showError = true
                            }
                        },
                        onCancel: {
                            self.parsedData = nil
                            self.scannedImage = nil
                            self.extractedText = ""
                        }
                    )
                } else {
                    Button {
                        showingCamera = true
                    } label: {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            Text("Scan Receipt")
                                .font(.title2)
                                .bold()
                            Text("Take a photo of your receipt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func processReceipt(image: UIImage) {
        isProcessing = true
        print("🔍 Starting receipt processing...")

        // Try AI scanner first (if API key is configured)
        OpenAIReceiptScanner.shared.scanReceipt(image: image) { aiResult in
            DispatchQueue.main.async {
                switch aiResult {
                case .success(let data):
                    print("✅ AI scan successful: \(data.storeName) - $\(data.total)")
                    self.extractedText = "Scanned with AI (GPT-5-nano)"
                    self.parsedData = data
                    self.isProcessing = false

                case .failure(let error):
                    print("⚠️ AI scan failed, trying Vision OCR: \(error.localizedDescription)")
                    // Fallback to Vision OCR
                    ReceiptScannerService.shared.recognizeText(from: image) { ocrResult in
                        DispatchQueue.main.async {
                            switch ocrResult {
                            case .success(let text):
                                print("✅ Vision OCR successful, extracted \(text.count) characters")
                                self.extractedText = text
                                self.parsedData = ReceiptScannerService.shared.parseReceipt(from: text)
                                self.isProcessing = false

                            case .failure(let error):
                                print("❌ Both AI and OCR failed: \(error.localizedDescription)")
                                // Still show review screen with empty data
                                self.extractedText = "Failed to extract text: \(error.localizedDescription)"
                                self.parsedData = ParsedReceiptData(
                                    storeName: "Unknown Store",
                                    date: Date(),
                                    items: [],
                                    total: 0.0
                                )
                                self.isProcessing = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Review Receipt View
struct ReviewReceiptView: View {
    let image: UIImage
    @State private var storeName: String
    @State private var totalAmount: Double
    @State private var selectedCategory: Category
    @State private var receiptDate: Date
    @State private var items: [ReceiptItem]
    @State private var showingRawText = false
    let extractedText: String
    let onSave: (Receipt) -> Void
    let onCancel: () -> Void

    init(image: UIImage, parsedData: ParsedReceiptData, extractedText: String, onSave: @escaping (Receipt) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.extractedText = extractedText
        self.onSave = onSave
        self.onCancel = onCancel

        _storeName = State(initialValue: parsedData.storeName.isEmpty ? "Unknown Store" : parsedData.storeName)
        _totalAmount = State(initialValue: parsedData.total)
        _receiptDate = State(initialValue: parsedData.date)
        _items = State(initialValue: parsedData.items)
        _selectedCategory = State(initialValue: ReceiptScannerService.shared.categorizeReceipt(
            storeName: parsedData.storeName,
            items: parsedData.items
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Receipt Image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)

                // Extracted Data Form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Review & Edit")
                        .font(.title2)
                        .bold()

                    // Store Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Store Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Store Name", text: $storeName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $receiptDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(Category.allCases, id: \.self) { category in
                                Label(category.rawValue, systemImage: category.icon)
                                    .tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // Total
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("$")
                            TextField("0.00", value: $totalAmount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                        }
                    }

                    // Items
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Items Found (\(items.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(items) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.caption)
                                    Spacer()
                                    Text("$\(item.price, specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }

                    // Show Raw Text Button
                    Button {
                        showingRawText = true
                    } label: {
                        Label("View Extracted Text", systemImage: "doc.text")
                            .font(.caption)
                    }
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        let receipt = Receipt(
                            date: receiptDate,
                            storeName: storeName,
                            totalAmount: totalAmount,
                            category: selectedCategory,
                            imageData: image.jpegData(compressionQuality: 0.7),
                            items: items,
                            rawText: extractedText
                        )
                        onSave(receipt)
                    } label: {
                        Text("Save Receipt")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }

                    Button {
                        onCancel()
                    } label: {
                        Text("Scan Again")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .sheet(isPresented: $showingRawText) {
            NavigationStack {
                ScrollView {
                    Text(extractedText.isEmpty ? "No text extracted" : extractedText)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .navigationTitle("Extracted Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showingRawText = false
                        }
                    }
                }
            }
        }
    }
}
