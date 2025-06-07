
import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    class Coordinator: NSObject, CameraViewControllerDelegate {
        var parent: CameraView

        init(parent: CameraView) {
            self.parent = parent
        }

        func didCapturePhoto(_ image: UIImage) {
            parent.capturedImage = image
        }
    }
}
