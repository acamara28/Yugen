import SwiftUI
import CoreLocation
import FirebaseStorage
import FirebaseAuth

struct CreatePostView: View {
    @State private var capturedImage: UIImage?
    @State private var title = ""
    @State private var labels = ""
    @State private var musicTitle = ""
    @State private var musicArtist = ""
    @State private var comment = ""
    @State private var isUploading = false
    @State private var uploadMessage = ""

    @StateObject private var locationManager = LocationManager() // ✅ use your utils/LocationManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)

                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField("Labels (comma-separated)", text: $labels)
                        .textFieldStyle(.roundedBorder)

                    TextField("Music Title", text: $musicTitle)
                        .textFieldStyle(.roundedBorder)

                    TextField("Music Artist", text: $musicArtist)
                        .textFieldStyle(.roundedBorder)

                    TextField("Special Instructions", text: $comment)
                        .textFieldStyle(.roundedBorder)

                    Button("Upload Post") {
                        uploadPost()
                    }
                    .disabled(isUploading)
                } else {
                    CameraView(capturedImage: $capturedImage)
                        .frame(height: 400)
                }

                if isUploading {
                    ProgressView(uploadMessage)
                }
            }
            .padding()
        }
        .onAppear {
            locationManager.requestLocationOnce() // ✅ one-time location request
        }
    }

    func uploadPost() {
        guard let image = capturedImage,
              let userId = Auth.auth().currentUser?.uid else { return }

        isUploading = true
        uploadMessage = "Uploading image..."

        uploadImageToFirebase(image: image) { result in
            switch result {
            case .success(let imageUrl):
                let music = MusicInfo(title: musicTitle, artist: musicArtist)

                let post = PostModel(
                    id: nil,
                    userId: userId,
                    username: "", // optional: fill with actual username if available
                    location: locationManager.userPlacemark?.locality ?? "", // ✅ optional readable location
                    title: title,
                    labels: labels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                    specialInstruction: comment,
                    music: music,
                    upvotes: 0,
                    downvotes: 0,
                    imageUrl: imageUrl,
                    createdAt: Date(),
                    latitude: locationManager.userLocation?.coordinate.latitude ?? 0.0,
                    longitude: locationManager.userLocation?.coordinate.longitude ?? 0.0
                )

                FirestorePostService.shared.createPost(post) { result in
                    isUploading = false
                    switch result {
                    case .success:
                        uploadMessage = "✅ Post uploaded successfully!"
                    case .failure(let error):
                        uploadMessage = "❌ Upload failed: \(error.localizedDescription)"
                    }
                }

            case .failure(let error):
                isUploading = false
                uploadMessage = "❌ Image upload failed: \(error.localizedDescription)"
            }
        }
    }

    func uploadImageToFirebase(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "image-error", code: 0)))
            return
        }

        let fileName = UUID().uuidString + ".jpg"
        let ref = Storage.storage().reference().child("post_images/\(fileName)")
        ref.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            ref.downloadURL { url, error in
                if let url = url {
                    completion(.success(url.absoluteString))
                } else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }
}
