import Foundation
import UIKit
import SwiftUI

class CameraService: NSObject, ObservableObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @Published var image: UIImage?
    @Published var didCapturePhoto = false

    func presentCamera(from viewController: UIViewController) {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.cameraCaptureMode = .photo
        viewController.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let capturedImage = info[.originalImage] as? UIImage {
            self.image = capturedImage
            self.didCapturePhoto = true
        }
        picker.dismiss(animated: true)
    }
}
