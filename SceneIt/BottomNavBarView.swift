import SwiftUI

struct BottomNavBarView: View {
    var body: some View {
        ZStack(alignment: .top) {
            MountainSilhouetteShape()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 30)
                .edgesIgnoringSafeArea(.bottom)

            HStack {
                Spacer()
                
                Image(systemName: "house")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                
                Spacer()
                
                Image(systemName: "map")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Spacer()
                
                Image(systemName: "camera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color.purple.opacity(0.7)) // lavender camera

                Spacer()
                
                Image(systemName: "person.3")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Spacer()
                
                Image(systemName: "person.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)

                Spacer()
            }
            .padding(.vertical, 10)
        }
    }
}

struct MountainSilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.5))
        path.addLine(to: CGPoint(x: width * 0.5, y: height))
        path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.3))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        
        return path
    }
}
