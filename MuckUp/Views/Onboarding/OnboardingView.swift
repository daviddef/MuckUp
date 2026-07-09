import SwiftUI

struct OnboardingPage {
    let stage: GrubLifecycleStage
    let mood: GrubMood
    let title: String
    let subtitle: String
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    // Walks Grub through its own lifecycle across the three pages — the
    // same metamorphosis story that plays out over real app usage,
    // previewed up front instead of three unrelated SF Symbols.
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            stage: .grub,
            mood: .idle,
            title: "Spot it",
            subtitle: "Notice a mess in your neighbourhood? Litter, illegal dumping, hazards — anything that needs cleaning up."
        ),
        OnboardingPage(
            stage: .bigGrub,
            mood: .celebrating,
            title: "Log it",
            subtitle: "Drop a pin, snap a photo, add a description. That evidence is what gets things fixed."
        ),
        OnboardingPage(
            stage: .fullFlight,
            mood: .celebrating,
            title: "Clean it up",
            subtitle: "Rally your community, schedule a cleanup event, and watch your impact add up — one bag at a time."
        )
    ]

    var body: some View {
        ZStack {
            Color.muckBg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: Spacing.md) {
                    if pageIndex == pages.count - 1 {
                        PrimaryButton(title: "Get Started", icon: "arrow.right") {
                            onFinish()
                        }
                    } else {
                        PrimaryButton(title: "Next") {
                            withAnimation { pageIndex += 1 }
                        }
                    }

                    Button("Skip") { onFinish() }
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.muckGreen.opacity(0.1))
                    .frame(width: 140, height: 140)
                GrubCharacterView(stage: page.stage, mood: page.mood, size: 92)
            }

            VStack(spacing: Spacing.sm) {
                Text(page.title)
                    .font(.muckDisplay)
                    .foregroundStyle(Color.muckNearBlack)
                Text(page.subtitle)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()
            Spacer()
        }
    }
}
