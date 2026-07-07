import SwiftUI

/// Account info, Junior Mode, and sign out — moved out of Profile's
/// toolbar Menu into a proper sheet. That menu was the right call with
/// two items in it; a third (Junior Mode) was the signal to stop
/// stacking toolbar icons/menu rows and give settings their own screen.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var muckVM: MuckViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if authService.isGuest {
                        Label("Guest mode — data stays on this device", systemImage: "person.crop.circle")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.7))
                    } else if let email = authService.currentUser?.email, !email.isEmpty {
                        Label(email, systemImage: "person.crop.circle")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack)
                    }
                }

                Section {
                    Toggle(isOn: $muckVM.isJuniorMode) {
                        Label("Junior Mode", systemImage: "figure.child")
                    }
                    .tint(Color.muckGreen)
                } footer: {
                    Text("Blurs your position on the map and only shows suburb-level location on new mucks.")
                }

                Section {
                    Button(role: .destructive) {
                        authService.signOut()
                        dismiss()
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
