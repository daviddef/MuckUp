import SwiftUI

/// Full-width celebratory banner that drops in from the top when the
/// user crosses into a new MuckRank, then auto-dismisses. Shown globally
/// (ContentView) so a rank-up anywhere in the app — raising a muck,
/// closing one, offering help — gets the same moment.
struct RankUpBanner: View {
    let rank: MuckRank
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var celebrate = false

    var body: some View {
        VStack {
            HStack(spacing: Spacing.sm) {
                GrubCharacterView(mood: .celebrating, size: 44)
                    .confettiBurst(trigger: $celebrate)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Rank Up!")
                        .font(.muckCaption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("You're now a \(rank.title)")
                        .font(.muckHeadline)
                        .foregroundStyle(.white)
                }

                Spacer()
            }
            .padding(Spacing.md)
            .background(LinearGradient.muckGrowth)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .muckFloatShadow()
            .padding(.horizontal, Spacing.md)
            .offset(y: isVisible ? 0 : -160)
            .opacity(isVisible ? 1 : 0)

            Spacer()
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                celebrate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
}
