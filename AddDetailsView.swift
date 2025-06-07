import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct AddDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let locationId: String

    @State private var musicTitle: String = ""
    @State private var musicArtist: String = ""
    @State private var specialInstructions: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isSubmitting: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Music")) {
                    TextField("Song Title", text: $musicTitle)
                    TextField("Artist", text: $musicArtist)
                }

                Section(header: Text("Special Instructions")) {
                    TextField("Add a note or tip for others", text: $specialInstructions)
                }

                Section(header: Text("Labels")) {
                    HStack {
                        TextField("Add a tag (e.g., sunset)", text: $newTag)
                        Button("Add") {
                            let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !tags.contains(trimmed) {
                                tags.append(trimmed)
                                newTag = ""
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(tags, id: \ .self) { tag in
                                Text(tag)
                                    .padding(6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                Section {
                    Button(action: submitDetails) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Save Details")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Enhance Location")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func submitDetails() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No user logged in")
            return
        }

        isSubmitting = true

        let data: [String: Any] = [
            "music": [
                "title": musicTitle,
                "artist": musicArtist
            ],
            "instructions": specialInstructions,
            "tags": tags,
            "timestamp": FieldValue.serverTimestamp()
        ]

        Firestore.firestore()
            .collection("location_details")
            .document(locationId)
            .collection("contributions")
            .document(userId)
            .setData(data) { error in
                isSubmitting = false

                if let error = error {
                    print("❌ Error saving details: \(error.localizedDescription)")
                } else {
                    print("✅ Details saved successfully")
                    presentationMode.wrappedValue.dismiss()
                }
            }
    }
}
