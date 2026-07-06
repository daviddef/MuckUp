import SwiftUI

/// The most convincing thing a cleanup app can show: the same spot,
/// before and after. A drag-to-reveal slider makes the transformation
/// feel immediate instead of two separate, static photos stacked in a
/// scroll view.
struct BeforeAfterSliderView: View {
    let beforeImage: UIImage
    let afterImage: UIImage

    @State private var revealFraction: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Image(uiImage: afterImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: geo.size.height)
                    .clipped()

                Image(uiImage: beforeImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: geo.size.height)
                    .clipped()
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: width * revealFraction)
                    }

                // Handle
                Rectangle()
                    .fill(.white)
                    .frame(width: 3)
                    .shadow(radius: 2)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.7))
                            )
                            .shadow(radius: 2)
                    )
                    .offset(x: width * revealFraction - 1.5)

                VStack {
                    HStack {
                        tag("Before")
                        Spacer()
                        tag("After")
                    }
                    Spacer()
                }
                .padding(Spacing.sm)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        revealFraction = min(1, max(0, value.location.x / width))
                    }
            )
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.muckMicro)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(.black.opacity(0.4))
            .clipShape(Capsule())
    }
}
