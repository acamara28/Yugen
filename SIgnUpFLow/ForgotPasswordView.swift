// LoginView.swift — Unified login with email, username, or phone (with password)

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginScreenView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var identifier = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var navigateToHome = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }

                Text("Welcome Back")
                    .font(.title)
                    .bold()

                TextField("Username, Email or Phone", text: $identifier)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                NavigationLink(destination: ForgotPasswordView()) {
                    Text("Forgot Password?")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                if isLoading {
                    ProgressView()
                } else {
                    Button("Log In") {
                        Task { await handleLogin() }
                    }
                    .disabled(identifier.isEmpty || password.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(identifier.isEmpty || password.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $navigateToHome) {
                HomeView()
            }
        }
    }

    // MARK: - Handle Login

    func handleLogin() async {
        errorMessage = ""
        isLoading = true

        do {
            let loginEmail: String
            if identifier.contains("@") {
                loginEmail = identifier.lowercased()
            } else if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: identifier)) && identifier.count >= 10 {
                // Assume it's a phone number
                loginEmail = "\(identifier.filter(\"0123456789\".contains))@sceneit.app"
            } else {
                // Assume it's a username → lookup
                let docs = try await Firestore.firestore().collection("users")
                    .whereField("username_lower", isEqualTo: identifier.lowercased())
                    .getDocuments()

                guard let userDoc = docs.documents.first,
                      let email = userDoc.data()["contact_email"] as? String else {
                    errorMessage = "Username not found."
                    isLoading = false
                    return
                }
                loginEmail = email
            }

            _ = try await Auth.auth().signIn(withEmail: loginEmail, password: password)
            navigateToHome = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
