import SwiftUI
import VisionKit

// MARK: - Document Camera View (SwiftUI Wrapper)
struct DocumentCameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        print(String(repeating: "=", count: 80))
        print("📷 DOCUMENT CAMERA INITIALIZING")
        print(String(repeating: "=", count: 80))
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView

        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            print(String(repeating: "=", count: 80))
            print("📸 CAMERA SCAN COMPLETED")
            print("Page count: \(scan.pageCount)")
            print(String(repeating: "=", count: 80))

            // Get the first scanned image
            guard scan.pageCount > 0 else {
                print("❌ No pages scanned")
                parent.dismiss()
                return
            }

            let image = scan.imageOfPage(at: 0)
            print("✅ Image captured: \(image.size.width)x\(image.size.height)")
            print("Calling onImageCaptured callback...")

            parent.onImageCaptured(image)
            print("✅ Callback executed, dismissing camera")
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            print(String(repeating: "=", count: 80))
            print("❌ CAMERA CANCELLED BY USER")
            print(String(repeating: "=", count: 80))
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            print(String(repeating: "=", count: 80))
            print("❌ CAMERA ERROR")
            print("Error: \(error)")
            print("Error description: \(error.localizedDescription)")
            print(String(repeating: "=", count: 80))
            parent.dismiss()
        }
    }
}
