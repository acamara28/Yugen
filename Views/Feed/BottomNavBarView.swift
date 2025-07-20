import SwiftUI

struct BottomNavBarView: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack {
            navButton(systemIcon: "house", index: 0)
            navButton(systemIcon: "map", index: 1)
            navButton(systemIcon: "camera", index: 2)
            navButton(systemIcon: "person.3", index: 3)
            navButton(systemIcon: "person.crop.circle", index: 4)
        }
        .padding()
        .background(Color.white.shadow(radius: 4))
    }

    func navButton(systemIcon: String, index: Int) -> some View {
        Button(action: {
            selectedTab = index
        }) {
            Image(systemName: systemIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 25, height: 25)
                .foregroundColor(selectedTab == index ? .blue : .gray)
        }
        .frame(maxWidth: .infinity)
    }
}
