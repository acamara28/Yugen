// LoginScreenView.swift

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginScreenView: View {
    // MARK: - State Properties
    @State private var identifier = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var navigateToHome = false
    @State private var showSignUp = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // MARK: - App Logo
                Image("app_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(.top, 40)

                // MARK: - Input Fields
                TextField("Email, Phone, or Username", text: $identifier)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // MARK: - Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                // MARK: - Login Button
                if isLoading {
                    ProgressView()
                } else {
                    Button("Login") {
                        Task {
                            await handleLogin()
                        }
                    }
                    .disabled(identifier.isEmpty || password.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(identifier.isEmpty || password.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                // MARK: - Forgot Password
                Button("Forgot password?") {
                    // To be implemented
                }
                .font(.footnote)
                .foregroundColor(.blue)

                // MARK: - Sign Up
                Button("Sign Up") {
                    showSignUp = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $navigateToHome) {
                HomeView()
            }
            .fullScreenCover(isPresented: $showSignUp) {
                SignUpUsernameView()
            }
        }
    }

    // MARK: - Login Logic
    func handleLogin() async {
        errorMessage = ""
        isLoading = true

        do {
            let db = Firestore.firestore()
            let usersRef = db.collection("users")

            if isValidEmail(identifier) {
                try await signInWith(email: identifier.lowercased(), password: password)
                return
            }

            if isValidPhone(identifier) {
                let phoneDigits = onlyDigits(from: identifier)
                let snapshot = try await usersRef
                    .whereField("contact_phone_digits", isEqualTo: phoneDigits)
                    .getDocuments()

                guard let data = snapshot.documents.first?.data(),
                      let email = data["contact_email"] as? String else {
                    throw NSError(domain: "SceneIt", code: 1, userInfo: [NSLocalizedDescriptionKey: "Phone number account not found or missing email."])
                }

                try await signInWith(email: email, password: password)
                return
            }

            let snapshot = try await usersRef
                .whereField("username_lower", isEqualTo: identifier.lowercased())
                .getDocuments()

            guard let data = snapshot.documents.first?.data(),
                  let email = data["contact_email"] as? String else {
                throw NSError(domain: "SceneIt", code: 2, userInfo: [NSLocalizedDescriptionKey: "Account not found for username."])
            }

            try await signInWith(email: email, password: password)

        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Firebase Sign-In
    func signInWith(email: String, password: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { _, error in
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    continuation.resume(throwing: error)
                } else {
                    navigateToHome = true
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Input Helpers
    func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }

    func isValidPhone(_ phone: String) -> Bool {
        onlyDigits(from: phone).count >= 10
    }

    func onlyDigits(from input: String) -> String {
        input.filter("0123456789".contains)
    }
}
