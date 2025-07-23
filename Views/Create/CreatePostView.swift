import SwiftUI
import FirebaseStorage
import FirebaseAuth
import CoreLocation
import PhotosUI

struct CreatePostView: View {
    @State private var capturedImage: UIImage?
    @State private var title = ""
    @State private var labels = ""
    @State private var specialInstruction = ""
    @State private var musicTitle = ""
    @State private var musicArtist = ""
    @State private var isShowingCamera = false
    @State private var isSubmitting = false
    @State private var currentLocation: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Show captured image
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                    } else {
                        Button(action: {
                            isShowingCamera = true
                        }) {
                            Label("Take Photo", systemImage: "camera.fill")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }

                    Group {
                        TextField("Title", text: $title)
                        TextField("Labels (comma separated)", text: $labels)
                        TextField("Add a note...", text: $specialInstruction)
                        TextField("Music Title", text: $musicTitle)
                        TextField("Artist", text: $musicArtist)
                    }
                    .textFieldStyle(.roundedBorder)

                    Button(action: uploadPost) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Post")
                                .bold()
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(isSubmitting || capturedImage == nil)
                }
                .padding()
                .onAppear(perform: fetchUserLocation)
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraView(image: $capturedImage)
            }
            .navigationTitle("Create Post")
        }
    }

    // MARK: - Upload Post
    private func uploadPost() {
        guard let image = capturedImage,
              let user = FirestoreUserService.shared.currentUser,
              let uid = Auth.auth().currentUser?.uid else { return }

        isSubmitting = true

        uploadImageToStorage(image: image) { result in
            switch result {
            case .success(let url):
                let post = PostModel(
                    userId: uid,
                    username: user.username,
                    location: "unknown",
                    title: title,
                    labels: labels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                    specialInstruction: specialInstruction,
                    music: MusicInfo(title: musicTitle, artist: musicArtist),
                    upvotes: 0,
                    downvotes: 0,
                    imageUrl: url,
                    createdAt: Date(),
                    latitude: currentLocation?.latitude,
                    longitude: currentLocation?.longitude
                )

                FirestorePostService.shared.createPost(post) { success in
                    isSubmitting = false
                    if success {
                        resetForm()
                    }
                }
            case .failure(let error):
                print("❌ Upload error: \(error.localizedDescription)")
                isSubmitting = false
            }
        }
    }

    private func resetForm() {
        capturedImage = nil
        title = ""
        labels = ""
        specialInstruction = ""
        musicTitle = ""
        musicArtist = ""
        currentLocation = nil
    }

    // MARK: - Upload Image
    private func uploadImageToStorage(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "Image error", code: 0)))
            return
        }

        let filename = UUID().uuidString
        let ref = Storage.storage().reference().child("post_images/\(filename).jpg")

        ref.putData(data, metadata: nil) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            ref.downloadURL { url, error in
                if let url = url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(error ?? NSError()))
                }
            }
        }
    }

    // MARK: - Location
    private func fetchUserLocation() {
        locationManager.requestWhenInUseAuthorization()
        if let loc = locationManager.location?.coordinate {
            currentLocation = loc
        }
    }
}
