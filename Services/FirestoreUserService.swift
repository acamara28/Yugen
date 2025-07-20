import FirebaseFirestore
class FirestoreUserService {
    static let shared = FirestoreUserService()
    private let db = Firestore.firestore()

    func saveUserData(uid: String, data: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("users").document(uid).setData(data, completion: completion)
    }

    func fetchUserData(uid: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = snapshot?.data() {
                completion(.success(data))
            } else {
                completion(.failure(NSError(domain: "UserNotFound", code: 404)))
            }
        }
    }

    func isUsernameAvailable(_ username: String, completion: @escaping (Bool) -> Void) {
        db.collection("users")
            .whereField("username_lower", isEqualTo: username.lowercased())
            .getDocuments { snapshot, error in
                completion(snapshot?.isEmpty ?? true)
            }
    }

    func isContactUnique(_ contactInfo: String, completion: @escaping (Bool) -> Void) {
        db.collection("users")
            .whereField("contactInfo", isEqualTo: contactInfo)
            .getDocuments { snapshot, error in
                completion(snapshot?.isEmpty ?? true)
            }
    }
}
