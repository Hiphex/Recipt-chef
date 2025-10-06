# Receipt Scanner & Budget Tracker

A native iOS app that uses Vision framework OCR to scan receipts, extract items/prices, and track spending against budgets.

## Features

✅ **Smart Receipt Scanning**
- Scan receipts with your camera using VNDocumentCameraViewController
- Automatic text recognition with Vision framework
- Extract store name, date, items, and prices
- Auto-categorization based on store name and items

✅ **Budget Management**
- Set monthly budgets for different spending categories
- Real-time spending tracking
- Visual progress bars
- Warnings when approaching or exceeding budget limits

✅ **Categories**
- Groceries
- Dining
- Shopping
- Transport
- Entertainment
- Health
- Utilities
- Other

✅ **Data Persistence**
- SwiftData for modern data management
- Store receipt images
- Full receipt history

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Physical device (Camera required for scanning)

## Setup Instructions

### 1. Create New Xcode Project

1. Open Xcode
2. File → New → Project
3. Choose **App** template
4. Product Name: `ReceiptScanner`
5. Interface: **SwiftUI**
6. Storage: **SwiftData**
7. Language: **Swift**

### 2. Add Files to Project

Drag all the `.swift` files into your Xcode project:
- `ReceiptScannerApp.swift` (replace the default one)
- `Models.swift`
- `ReceiptScannerService.swift`
- `DocumentCameraView.swift`
- `ReceiptViews.swift`
- `BudgetView.swift`

### 3. Configure Capabilities

#### Add Camera Permission
1. Select your project in the navigator
2. Select your target
3. Go to **Info** tab
4. Add these keys to **Custom iOS Target Properties**:
   - **Privacy - Camera Usage Description**: "We need camera access to scan receipts"
   - **Privacy - Photo Library Usage Description**: "We need photo library access to save scanned receipts"

### 4. Build and Run

1. Select a physical iOS device (not simulator - camera required)
2. Click the **Play** button or `Cmd + R`
3. Allow camera permissions when prompted

## How to Use

### Scanning Your First Receipt

1. Tap the **+** button in the top right
2. Position your receipt in the camera view
3. The app will automatically detect and capture the receipt
4. Wait for OCR processing
5. Review the extracted data

### Setting Budgets

1. Tap the **chart icon** in the top left
2. Tap **+** to create a new budget
3. Select a category and monthly limit
4. Save

### Tracking Spending

- Receipts are automatically categorized
- View real-time spending in the Budget screen
- Progress bars show how much of your budget is used
- Get warnings at 90% and when over budget

## Architecture

```
ReceiptScanner/
├── Models.swift                    # SwiftData models (Receipt, ReceiptItem, Budget, Category)
├── ReceiptScannerService.swift     # Vision OCR + Receipt parsing logic
├── DocumentCameraView.swift        # Camera capture wrapper
├── ReceiptViews.swift              # Main UI (List, Detail, Scan)
├── BudgetView.swift                # Budget management UI
└── ReceiptScannerApp.swift         # App entry point
```

## How It Works

### OCR Pipeline
1. **Capture**: VNDocumentCameraViewController captures high-quality receipt image
2. **Recognition**: VNRecognizeTextRequest extracts text with `.accurate` mode
3. **Parsing**: Regex patterns extract items, prices, totals, dates
4. **Categorization**: Smart categorization based on store name and items
5. **Storage**: Save to SwiftData with image attachment

### Budget Tracking
1. Calculate monthly spending per category
2. Compare against set budget limits
3. Update progress bars in real-time
4. Show warnings when approaching/exceeding limits

## Customization Ideas

- Add export to CSV/PDF
- Integrate with receipt APIs for better parsing
- Add machine learning for better categorization
- Create spending charts and analytics
- Add search and filtering
- Multi-currency support
- Shared budgets (CloudKit sync)

## Known Limitations

- Receipt parsing accuracy depends on image quality
- Some receipt formats may not parse perfectly
- Store name extraction works best with standard receipt layouts
- Requires manual adjustment for edge cases

## Troubleshooting

**Camera not working?**
- Make sure you're running on a physical device
- Check camera permissions in Settings → ReceiptScanner

**OCR not accurate?**
- Ensure good lighting when scanning
- Hold camera steady
- Make sure receipt is flat and in focus

**App won't build?**
- Ensure iOS deployment target is 17.0+
- Clean build folder: Product → Clean Build Folder
- Restart Xcode

## Future Enhancements

- [ ] Cloud sync with iCloud
- [ ] Receipt sharing
- [ ] Advanced analytics dashboard
- [ ] Recurring expense detection
- [ ] Multi-user support
- [ ] Dark mode optimization
- [ ] Widget for quick budget overview
- [ ] Notification reminders for budget limits

## License

MIT License - Feel free to use and modify!

---

Built with ❤️ using SwiftUI, Vision, and SwiftData
