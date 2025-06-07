//
//  SignUpContactView.swift
//  SceneIt
//
//  Created by Alpha  Camara on 6/7/25.
//
import SwiftUI
import Firebase
import FirebaseAuth

struct SignUpContactView: View {
    var username: String
    var fullName: String
    var dateOfBirth: String

    @Environment(\.dismiss) var dismiss
    @State private var contact = ""
    @State private var contactError = ""
    @State private var goToVerify = false
    @State private var contactType: ContactType = .phone
    @State private var isSending = false
    @State private var canResend = true
    @State private var countdown = 0
    @State private var verificationID: String? = nil
    @State private var createdUser: User? = nil

    enum ContactType: String, CaseIterable, Identifiable {
        case phone = "Phone"
        case email = "Email"
        var id: String { self.rawValue }
    }

    var body: some View {
        VStack(spacing: 25) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                Spacer()
            }

            Text("Add Phone or Email")
                .font(.title2)
                .bold()

            Picker("Contact Type", selection: $contactType) {
                ForEach(ContactType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Group {
                if contactType == .phone {
                    TextField("Phone Number", text: $contact)
                        .keyboardType(.phonePad)
                } else {
                    TextField("Email", text: $contact)
                        .keyboardType(.emailAddress)
                }
            }
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if !contactError.isEmpty {
                Text(contactError)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if isSending {
                ProgressView()
            } else {
                Button("Send Verification Code") {
                    Task { await validateAndSend() }
                }
                .disabled(!canResend || contact.isEmpty)
                .frame(maxWidth: .infinity)
                .padding()
                .background((!canResend || contact.isEmpty) ? Color.gray : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            if !canResend {
                Text("Resend available in \(countdown)s")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $goToVerify) {
            VerificationCodeView(
                contact: formattedContactForFirebase(),
                verificationID: verificationID ?? UUID().uuidString,
                username: username,
                fullName: fullName,
                dateOfBirth: dateOfBirth,
                contactType: contactType,
                createdUser: createdUser
            )
        }
    }

    func validateAndSend() async {
        contactError = ""
        isSending = true
        canResend = false
        countdown = 15
        startResendTimer()

        let isPhone = contactType == .phone
        let isValid = isPhone
            ? NSPredicate(format: "SELF MATCHES %@", "^\\d{10,15}$").evaluate(with: contact.filter("0123456789".contains))
            : NSPredicate(format: "SELF MATCHES %@", "^\\S+@\\S+\\.\\S+$").evaluate(with: contact)

        guard isValid else {
            isSending = false
            contactError = isPhone ? "Enter a valid phone number." : "Enter a valid email."
            return
        }

        if isPhone {
            let phoneDigits = contact.filter("0123456789".contains)
            PhoneAuthProvider.provider().verifyPhoneNumber("+1\(phoneDigits)", uiDelegate: nil) { verificationID, error in
                isSending = false
                if let error = error {
                    self.contactError = "Failed to send SMS: \(error.localizedDescription)"
                    return
                }
                self.verificationID = verificationID
                self.contact = phoneDigits // Ensure only digits go forward
                self.goToVerify = true
            }
        } else {
            Auth.auth().createUser(withEmail: contact, password: UUID().uuidString) { result, error in
                isSending = false
                if let error = error {
                    self.contactError = "Verification failed: \(error.localizedDescription)"
                    return
                }
                self.createdUser = result?.user
                result?.user.sendEmailVerification { err in
                    if let err = err {
                        self.contactError = "Email send failed: \(err.localizedDescription)"
                        return
                    }
                    self.verificationID = result?.user.uid
                    self.goToVerify = true
                }
            }
        }
    }

    func formattedContactForFirebase() -> String {
        contactType == .phone ? contact.filter("0123456789".contains) : contact.lowercased()
    }

    func startResendTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                canResend = true
                timer.invalidate()
            }
        }
    }
}
