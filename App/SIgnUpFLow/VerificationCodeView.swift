//
//  VerificationCodeView.swift
//  SceneIt
//
//  Created by Alpha  Camara on 6/13/25.
//
// VerificationCodeView.swift — Final step of hybrid auth flow (SMS/Email), with retry, validation, and Firestore storage + re-verification logic

import SwiftUI
import FirebaseAuth

struct VerificationCodeView: View {
    var contact: String
    @State var verificationID: String
    var username: String
    var fullName: String
    var dateOfBirth: String
    var contactType: SignUpContactView.ContactType
    var createdUser: User?

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isVerifying = false
    @State private var errorMessage = ""
    @State private var retryCountdown = 0
    @State private var canRetry = true
    @State private var showResendSuccess = false
    @State private var goToPassword = false
    @State private var phoneCredential: PhoneAuthCredential? = nil

    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                Spacer()
            }

            Text("Verify Your \(contactType.rawValue)")
                .font(.title2)
                .bold()

            if contactType == .phone {
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .disabled(isVerifying)

                Button("Verify") {
                    validatePhone()
                }
                .disabled(code.count != 6)
                .frame(maxWidth: .infinity)
                .padding()
                .background(code.count == 6 ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)

                if !canRetry {
                    Text("Retry available in \(retryCountdown)s")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    Button("Resend Code") {
                        resendCode()
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }

                if showResendSuccess {
                    Text("Verification code resent")
                        .font(.caption)
                        .foregroundColor(.green)
                }

            } else {
                Text("Check your email for a verification link.\nThen tap continue.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button("Continue") {
                    validateEmail()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if isVerifying {
                ProgressView()
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if contactType == .phone {
                startRetryCountdown()
            }
        }
        .fullScreenCover(isPresented: $goToPassword) {
            SignUpPasswordView(
                username: username,
                fullName: fullName,
                dateOfBirth: dateOfBirth,
                contactInfo: sanitizedContact(),
                phoneCredential: phoneCredential
            )
        }
    }

    /// Strips contact down to digits for phone, or passes full email.
    func sanitizedContact() -> String {
        if contactType == .phone {
            return contact.filter("0123456789".contains)
        } else {
            return contact
        }
    }

    func validatePhone() {
        errorMessage = ""
        isVerifying = true

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        self.phoneCredential = credential
        self.isVerifying = false
        self.goToPassword = true
    }

    func validateEmail() {
        guard let user = createdUser else {
            errorMessage = "Temporary user missing. Please restart."
            return
        }

        isVerifying = true
        user.reload { err in
            isVerifying = false
            if let err = err {
                errorMessage = err.localizedDescription
                return
            }
            if user.isEmailVerified {
                goToPassword = true
            } else {
                errorMessage = "Email not verified yet. Please check your inbox."
            }
        }
    }

    func resendCode() {
        showResendSuccess = false
        let formatted = contact.hasPrefix("+") ? contact : "+1\(contact)"
        PhoneAuthProvider.provider().verifyPhoneNumber(formatted, uiDelegate: nil) { newID, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            self.verificationID = newID ?? self.verificationID
            showResendSuccess = true
            startRetryCountdown()
        }
    }

    func startRetryCountdown() {
        canRetry = false
        retryCountdown = 15
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            retryCountdown -= 1
            if retryCountdown <= 0 {
                canRetry = true
                timer.invalidate()
            }
        }
    }
}
