import SwiftUI

struct CameraPageView: View {
    @State private var capturedImage: UIImage?
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding()

                Button("Retake Photo") {
                    capturedImage = nil
                }
                .foregroundColor(.red)
            } else {
                CameraView(image: $capturedImage)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .navigationTitle("Camera")
        .navigationBarTitleDisplayMode(.inline)
    }
}
