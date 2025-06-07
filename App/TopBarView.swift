import SwiftUI

struct TopBarView: View {
    var body: some View {
        HStack {
            Text("Yugen")
                .font(.title.bold())
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "bell")
                .font(.title2)
        }
        .padding()
        .background(Color.white)
    }
}
