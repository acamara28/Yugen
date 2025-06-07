import UIKit
import AVFoundation

protocol CameraViewControllerDelegate: AnyObject {
    func didCapturePhoto(_ image: UIImage)
}

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: CameraViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCamera()
        addCaptureButton()
    }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else {
            print("❌ Camera setup failed")
            return
        }

        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    private func addCaptureButton() {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        button.layer.cornerRadius = 35
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 2
        button.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)

        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 70),
            button.heightAnchor.constraint(equalToConstant: 70)
        ])
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("❌ Failed to process captured photo")
            return
        }

        delegate?.didCapturePhoto(image)
        captureSession.stopRunning()
    }
}
