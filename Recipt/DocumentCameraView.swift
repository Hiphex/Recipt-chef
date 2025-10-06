import SwiftUI
import VisionKit

// MARK: - Document Camera View (SwiftUI Wrapper)
struct DocumentCameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
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
            // Get the first scanned image
            guard scan.pageCount > 0 else {
                parent.dismiss()
                return
            }

            let image = scan.imageOfPage(at: 0)
            parent.onImageCaptured(image)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            print("Document camera error: \(error.localizedDescription)")
            parent.dismiss()
        }
    }
}
