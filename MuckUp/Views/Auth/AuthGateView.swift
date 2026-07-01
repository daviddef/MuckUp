import SwiftUI
import AuthenticationServices

struct AuthGateView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Spacing.md) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                Text("Welcome to Grub")
                    .font(.muckDisplay)
                    .foregroundStyle(Color.muckNearBlack)

                Text("Sign in to sync your mucks, events, and impact across your devices.")
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            VStack(spacing: Spacing.sm) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authService.handleSignInResult(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                Button {
                    authService.continueAsGuest()
                } label: {
                    Text("Continue as Guest")
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }
                .padding(.top, Spacing.xxs)

                Text("Guest data stays on this device only and won't sync.")
                    .font(.muckMicro)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.muckBg.ignoresSafeArea())
    }
}
