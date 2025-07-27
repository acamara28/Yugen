import SwiftUI
import FirebaseAuth

struct ForgotPasswordView: View {
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var message = ""
    @State private var isSuccess = false

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                Spacer()
            }

            Text("Reset Password")
                .font(.title)
                .bold()

            TextField("Enter your email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(isSuccess ? .green : .red)
                    .font(.caption)
            }

            Button("Send Reset Link") {
                sendPasswordReset()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)

            Spacer()
        }
        .padding()
    }

    func sendPasswordReset() {
        message = ""
        guard !email.isEmpty else {
            message = "Please enter your email."
            isSuccess = false
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                message = error.localizedDescription
                isSuccess = false
            } else {
                message = "Reset link sent! Check your email."
                isSuccess = true
            }
        }
    }
}
