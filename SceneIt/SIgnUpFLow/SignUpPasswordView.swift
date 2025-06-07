import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SignUpPasswordView: View {
    var username: String
    var fullName: String
    var dateOfBirth: String
    var contactInfo: String
    var phoneCredential: PhoneAuthCredential? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isCreating = false
    @State private var navigateToHome = false

    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                Spacer()
            }

            Text("Create Password")
                .font(.title)
                .bold()

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            SecureField("Confirm Password", text: $confirmPassword)
                .textContentType(.newPassword)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 5) {
                Text("Password must contain:")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Label("At least 8 characters", systemImage: isAtLeast8 ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isAtLeast8 ? .green : .gray)
                Label("One uppercase letter", systemImage: hasUppercase ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(hasUppercase ? .green : .gray)
                Label("One number", systemImage: hasNumber ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(hasNumber ? .green : .gray)
                Label("Passwords match", systemImage: passwordsMatch ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(passwordsMatch ? .green : .gray)
            }
            .font(.caption)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if isCreating {
                ProgressView()
            } else {
                Button("Create Account") {
                    Task { await createAccount() }
                }
                .disabled(!isPasswordValid)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isPasswordValid ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $navigateToHome) {
            HomeView()
        }
    }

    // MARK: - Password Rules

    var isAtLeast8: Bool { password.count >= 8 }
    var hasUppercase: Bool { password.range(of: "[A-Z]", options: .regularExpression) != nil }
    var hasNumber: Bool { password.range(of: "\\d", options: .regularExpression) != nil }
    var passwordsMatch: Bool { password == confirmPassword && !confirmPassword.isEmpty }
    var isPasswordValid: Bool { isAtLeast8 && hasUppercase && hasNumber && passwordsMatch }

    // MARK: - Account Creation

    func createAccount() async {
        errorMessage = ""
        isCreating = true

        guard let credential = phoneCredential else {
            errorMessage = "Verification is missing. Please restart signup."
            isCreating = false
            return
        }

        do {
            let authResult = try await Auth.auth().signIn(with: credential)
            let user = authResult.user

            // Create an internal login email based on phone number
            let sanitizedPhone = contactInfo.filter("0123456789".contains)
            let loginEmail = "\(sanitizedPhone)@sceneit.app"

            // Link this phone account with an email/password credential
            let passwordCredential = EmailAuthProvider.credential(withEmail: loginEmail, password: password)
            try await user.link(with: passwordCredential)

            // Store user data and navigate home
            storeUserData(uid: user.uid, linkedEmail: loginEmail)

        } catch {
            errorMessage = "Account creation failed: \(error.localizedDescription)"
            isCreating = false
        }
    }

    // MARK: - Store Profile in Firestore

    func storeUserData(uid: String, linkedEmail: String) {
        let db = Firestore.firestore()
        let userDocRef = db.collection("users").document(uid)

        let sanitizedDigits = contactInfo.filter("0123456789".contains)

        let data: [String: Any] = [
            "username": username,
            "username_lower": username.lowercased(),
            "fullName": fullName,
            "dateOfBirth": dateOfBirth,
            "uid": uid,
            "createdAt": FieldValue.serverTimestamp(),
            "contact_phone": contactInfo,
            "contact_phone_digits": sanitizedDigits,
            "authMethod": "phone_password",
            "contact_email": linkedEmail  // used for login with password
        ]

        userDocRef.setData(data) { error in
            isCreating = false
            if let error = error {
                self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
            } else {
                self.navigateToHome = true
            }
        }
    }
}
