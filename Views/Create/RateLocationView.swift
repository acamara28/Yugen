import SwiftUI
import Firebase
import FirebaseFirestore

struct RateLocationView: View {
    let locationId: String
    let userId: String // you can pass from Auth if needed
    
    @State private var rating: Double = 5.0
    @State private var isSubmitting = false
    @State private var submitSuccess = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Text("Rate this spot")
                .font(.title2)
                .bold()

            Text("How would you rate this location from 1 to 10?")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Slider(value: $rating, in: 1...10, step: 1)
                .padding(.horizontal)
            
            Text("Rating: \(Int(rating))")
                .font(.headline)

            Button(action: submitRating) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Submit Rating")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }

            if submitSuccess {
                Text("✅ Thanks for your rating!")
                    .foregroundColor(.green)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Rate Location")
    }

    private func submitRating() {
        isSubmitting = true

        let db = Firestore.firestore()
        let ratingsRef = db.collection("location_ratings").document(locationId).collection("ratings").document(userId)

        let data: [String: Any] = [
            "rating": Int(rating),
            "timestamp": FieldValue.serverTimestamp()
        ]

        ratingsRef.setData(data) { error in
            isSubmitting = false
            if let error = error {
                print("❌ Error submitting rating: \(error.localizedDescription)")
                return
            }

            submitSuccess = true

            // Optional: update average rating in a summary document
            updateAverageRating()
        }
    }

    private func updateAverageRating() {
        let db = Firestore.firestore()
        let ratingsCollection = db.collection("location_ratings").document(locationId).collection("ratings")

        ratingsCollection.getDocuments { snapshot, error in
            guard let docs = snapshot?.documents else { return }

            let allRatings = docs.compactMap { $0.data()["rating"] as? Int }
            guard !allRatings.isEmpty else { return }

            let average = Double(allRatings.reduce(0, +)) / Double(allRatings.count)

            db.collection("location_ratings").document(locationId).setData([
                "averageRating": average,
                "totalRatings": allRatings.count
            ], merge: true)
        }
    }
}
