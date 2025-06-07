
import Foundation
import FirebaseStorage

class ImageUploader {
    static let shared = ImageUploader()

    func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageError", code: 0, userInfo: nil)))
            return
        }

        let filename = UUID().uuidString
        let ref = Storage.storage().reference(withPath: "images/\(filename)")

        ref.putData(imageData) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
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
}
