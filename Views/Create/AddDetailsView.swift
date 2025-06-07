import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

let predefinedTags = [
    "sunset", "urban", "forest", "ocean", "mountain",
    "cityscape", "night", "sunrise", "desert", "historical"
]

struct AddDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    let locationId: String

    @State private var musicTitle: String = ""
    @State private var musicArtist: String = ""
    @State private var specialInstructions: String = ""
    @State private var tags: [String] = []
    @State private var rating: Int = 5
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

                Section(header: Text("Select Tags")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(predefinedTags, id: \.self) { tag in
                            Button(action: {
                                if tags.contains(tag) {
                                    tags.removeAll { $0 == tag }
                                } else {
                                    tags.append(tag)
                                }
                            }) {
                                Text(tag.capitalized)
                                    .padding(8)
                                    .background(tags.contains(tag) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(tags.contains(tag) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Rate This Location")) {
                    Stepper(value: $rating, in: 1...10) {
                        Text("Rating: \(rating)/10")
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

        let userContributionRef = Firestore.firestore()
            .collection("location_details")
            .document(locationId)
            .collection("contributions")
            .document(userId)

        let locationMetaRef = Firestore.firestore()
            .collection("location_details")
            .document(locationId)

        let contributionData: [String: Any] = [
            "music": [
                "title": musicTitle,
                "artist": musicArtist
            ],
            "instructions": specialInstructions,
            "tags": tags,
            "rating": rating,
            "timestamp": FieldValue.serverTimestamp()
        ]

        let batch = Firestore.firestore().batch()

        batch.setData(contributionData, forDocument: userContributionRef)

        batch.setData([
            "ratingCount": FieldValue.increment(Int64(1)),
            "ratingTotal": FieldValue.increment(Int64(rating))
        ], forDocument: locationMetaRef, merge: true)

        batch.commit { error in
            isSubmitting = false

            if let error = error {
                print("❌ Error saving details: \(error.localizedDescription)")
            } else {
                print("✅ Details & rating saved successfully")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
