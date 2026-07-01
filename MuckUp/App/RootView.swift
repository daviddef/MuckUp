import SwiftUI

/// Top-level flow: splash → (first-run) onboarding → main tabs.
struct RootView: View {
    @State private var showSplash = true
    @State private var showOnboarding = !StorageService.shared.hasSeenOnboarding()

    var body: some View {
        ZStack {
            ContentView()

            if showOnboarding && !showSplash {
                OnboardingView {
                    StorageService.shared.setHasSeenOnboarding()
                    withAnimation { showOnboarding = false }
                }
                .transition(.opacity)
            }

            if showSplash {
                SplashView {
                    showSplash = false
                }
                .zIndex(1)
            }
        }
    }
}
