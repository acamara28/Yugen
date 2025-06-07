//
//  SignUpUsernameView.swift
//  SceneIt
//
//  Created by Alpha  Camara on 6/7/25.
//
import SwiftUI
import Firebase

struct SignUpUsernameView: View {
    @Environment(\.dismiss) var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var dateOfBirth = Date()

    @State private var isValid = false
    @State private var isUsernameAvailable = true
    @State private var checkingUsername = false
    @State private var goNext = false

    @FocusState private var usernameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 25) {
            Text("Create Your Account")
                .font(.title2)
                .bold()

            TextField("First Name", text: $firstName)
                .textInputAutocapitalization(.words)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            TextField("Last Name", text: $lastName)
                .textInputAutocapitalization(.words)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            TextField("Username (3–30 characters, no spaces)", text: $username)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .focused($usernameFieldFocused)
                .onSubmit {
                    checkUsernameAvailabilityAndContinue()
                }

            if checkingUsername {
                ProgressView().scaleEffect(0.5)
            }

            if !isUsernameAvailable && !username.isEmpty {
                Text("Username is already taken")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                .padding()

            if !isValid && (!firstName.isEmpty || !lastName.isEmpty || !username.isEmpty) {
                Text("Complete all fields correctly. Must be 16+ years old.")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button("Next") {
                checkUsernameAvailabilityAndContinue()
            }
            .disabled(!allFieldsEntered())
            .frame(maxWidth: .infinity)
            .padding()
            .background(allFieldsEntered() ? Color.purple : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)

            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $goNext) {
            let fullName = "\(firstName) \(lastName)"
            SignUpContactView(username: username, fullName: fullName, dateOfBirth: formatDate(dateOfBirth))
        }
    }

    func allFieldsEntered() -> Bool {
        let validUsername = username.count >= 3 && username.count <= 30 && !username.contains(" ")
        let ageRequirement = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
        return !firstName.isEmpty &&
               !lastName.isEmpty &&
               validUsername &&
               dateOfBirth <= ageRequirement
    }

    func checkUsernameAvailabilityAndContinue() {
        if !allFieldsEntered() { return }
        checkingUsername = true
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("username_lower", isEqualTo: username.lowercased())
            .getDocuments { snapshot, error in
                checkingUsername = false
                if let error = error {
                    print("Error checking username: \(error.localizedDescription)")
                    isUsernameAvailable = false
                    return
                }
                isUsernameAvailable = snapshot?.documents.isEmpty ?? true
                validateAndProceed()
            }
    }

    func validateAndProceed() {
        let validUsername = username.count >= 3 && username.count <= 30 && !username.contains(" ")
        let ageRequirement = Calendar.current.date(byAdding: .year, value: -16, to: Date()) ?? Date()
        isValid = !firstName.isEmpty &&
                  !lastName.isEmpty &&
                  validUsername &&
                  isUsernameAvailable &&
                  dateOfBirth <= ageRequirement

        if isValid {
            goNext = true
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}
