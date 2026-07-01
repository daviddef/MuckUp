import Foundation
import AuthenticationServices
import SwiftUI

/// Sign in with Apple wrapper. Apple only hands you the user's name/email
/// on the very first authorization ever — every subsequent sign-in only
/// returns the stable user identifier, so we cache the profile locally
/// the first time we see it.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var isRestoring = true

    private let defaults = UserDefaults.standard
    private let appleUserIdKey = "auth_appleUserId"
    private let cachedProfileKey = "auth_cachedProfile"

    var isSignedIn: Bool { currentUser != nil }
    var isGuest: Bool { currentUser?.id == AppUser.guest.id }

    // MARK: - Restore on launch

    /// Checks whether a previously-stored Apple credential is still valid.
    /// Falls back to signed-out if it was revoked (user removed the app's
    /// access in Settings > Apple ID > Sign in with Apple).
    func restoreSession() async {
        defer { isRestoring = false }

        guard let appleUserId = defaults.string(forKey: appleUserIdKey) else { return }

        let provider = ASAuthorizationAppleIDProvider()
        let state = await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: appleUserId) { state, _ in
                continuation.resume(returning: state)
            }
        }

        switch state {
        case .authorized:
            currentUser = loadCachedProfile(appleUserId: appleUserId)
        case .revoked, .notFound:
            signOut()
        default:
            break
        }
    }

    // MARK: - Sign in with Apple

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let appleUserId = credential.user

            // Only present on first-ever sign-in for this app/user pair.
            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let email = credential.email

            defaults.set(appleUserId, forKey: appleUserIdKey)

            var profile = loadCachedProfile(appleUserId: appleUserId)
                ?? AppUser(id: appleUserId, email: email ?? "", displayName: displayName.isEmpty ? "Neighbour" : displayName, points: 0)

            if !displayName.isEmpty { profile.displayName = displayName }
            if let email, !email.isEmpty { profile.email = email }

            cacheProfile(profile)
            currentUser = profile

        case .failure(let error):
            let nsError = error as NSError
            // User cancelling the sheet isn't an error worth surfacing.
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                print("Sign in with Apple failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Guest mode

    func continueAsGuest() {
        currentUser = AppUser.guest
    }

    // MARK: - Sign out

    func signOut() {
        defaults.removeObject(forKey: appleUserIdKey)
        defaults.removeObject(forKey: cachedProfileKey)
        currentUser = nil
    }

    // MARK: - Local profile cache

    private func cacheProfile(_ user: AppUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        defaults.set(data, forKey: cachedProfileKey)
    }

    private func loadCachedProfile(appleUserId: String) -> AppUser? {
        guard let data = defaults.data(forKey: cachedProfileKey),
              let user = try? JSONDecoder().decode(AppUser.self, from: data),
              user.id == appleUserId else { return nil }
        return user
    }
}
