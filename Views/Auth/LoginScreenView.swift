import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginScreenView: View {
    @State private var identifier = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var goToMainApp = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Log In to SceneIt")
                    .font(.title)
                    .bold()

                TextField("Phone, Email, or Username", text: $identifier)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
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

                if isLoading {
                    ProgressView()
                } else {
                    Button("Log In") {
                        Task { await loginUser() }
                    }
                    .disabled(identifier.isEmpty || password.isEmpty)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((identifier.isEmpty || password.isEmpty) ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $goToMainApp) {
                MainTabController()
            }
        }
    }

    // MARK: - Login Logic
    func loginUser() async {
        errorMessage = ""
        isLoading = true

        let emailToUse: String

        if identifier.contains("@") {
            // Email login
            emailToUse = identifier.lowercased()
        } else if identifier.allSatisfy({ $0.isNumber }) {
            // Phone login
            let digits = identifier.filter("0123456789".contains)
            emailToUse = "\(digits)@sceneit.app"
        } else {
            // Username login → lookup contact_email
            do {
                let result = try await Firestore.firestore()
                    .collection("users")
                    .whereField("username_lower", isEqualTo: identifier.lowercased())
                    .getDocuments()
                
                guard let doc = result.documents.first,
                      let contactEmail = doc.data()["contact_email"] as? String else {
                    self.errorMessage = "Username not found."
                    self.isLoading = false
                    return
                }
                emailToUse = contactEmail
            } catch {
                self.errorMessage = "Error finding username: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
        }

        // Try login with resolved email
        do {
            try await Auth.auth().signIn(withEmail: emailToUse, password: password)
            self.goToMainApp = true
        } catch {
            self.errorMessage = "Login failed: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
