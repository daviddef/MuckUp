import SwiftUI

/// Top-level flow: splash → sign in → (first-run) onboarding → main tabs.
struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var eventVM: EventViewModel
    @EnvironmentObject var helpVM: HelpViewModel

    @State private var showSplash = true
    @State private var showOnboarding = !StorageService.shared.hasSeenOnboarding()

    var body: some View {
        ZStack {
            if authService.isSignedIn {
                ContentView()
                    .transition(.opacity)
            }

            if showOnboarding && !showSplash && authService.isSignedIn {
                OnboardingView {
                    StorageService.shared.setHasSeenOnboarding()
                    withAnimation { showOnboarding = false }
                }
                .transition(.opacity)
            }

            if !showSplash && !authService.isSignedIn && !authService.isRestoring {
                AuthGateView()
                    .transition(.opacity)
            }

            if showSplash {
                SplashView {
                    withAnimation { showSplash = false }
                }
                .zIndex(1)
            }
        }
        .task {
            await authService.restoreSession()
        }
        .onChange(of: authService.currentUser?.id) { _, newId in
            guard let newId else { return }
            muckVM.updateUser(newId)
            eventVM.userId = newId
            helpVM.userId = newId
        }
    }
}
