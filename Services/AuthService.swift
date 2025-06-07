import FirebaseAuth
class AuthService {
    static let shared = AuthService()

    func registerUser(email: String, password: String, userData: [String: Any], completion: @escaping (Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            guard let user = result?.user, error == nil else {
                completion(error)
                return
            }
            FirestoreUserService.shared.saveUserData(uid: user.uid, data: userData, completion: completion)
        }
    }

    func loginUser(email: String, password: String, completion: @escaping (AuthDataResult?, Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password, completion: completion)
    }

    func resetPassword(email: String, completion: @escaping (Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email, completion: completion)
    }
}
