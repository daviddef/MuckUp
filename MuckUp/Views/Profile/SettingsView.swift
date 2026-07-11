import SwiftUI
import SwiftData

/// Account info, Junior Mode, and sign out — moved out of Profile's
/// toolbar Menu into a proper sheet. That menu was the right call with
/// two items in it; a third (Junior Mode) was the signal to stop
/// stacking toolbar icons/menu rows and give settings their own screen.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var muckVM: MuckViewModel

    @State private var showDeleteConfirmation = false
    // Local mirror of the blocked list so unblocking updates the rows
    // immediately without needing MuckViewModel to be @Published per-id.
    @State private var blockedOwnerIds: [String] = []

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

                if !blockedOwnerIds.isEmpty {
                    Section {
                        ForEach(blockedOwnerIds, id: \.self) { ownerId in
                            HStack {
                                Label("Blocked user", systemImage: "person.slash")
                                    .font(.muckBody)
                                Spacer()
                                Button("Unblock") {
                                    muckVM.unblockOwner(ownerId)
                                    blockedOwnerIds = muckVM.blockedOwnerIds
                                }
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckGreen)
                            }
                        }
                    } header: {
                        Text("Blocked Users")
                    } footer: {
                        Text("You won't see mucks from blocked users. Unblock to see them again.")
                    }
                }

                Section {
                    Link(destination: URL(string: "https://daviddef.github.io/MuckUp/terms.html")!) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    Link(destination: URL(string: "https://daviddef.github.io/MuckUp/privacy.html")!) {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                } header: {
                    Text("About")
                }

                if !authService.isGuest {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Account")
                        }
                    } footer: {
                        Text("Permanently deletes your mucks, events, and profile. This can't be undone.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { blockedOwnerIds = muckVM.blockedOwnerIds }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes every muck and event you've created, along with your profile. This can't be undone.")
            }
        }
    }

    // Deletes everything the current user owns before signing out — Apple
    // guideline 5.1.1(v) requires in-app account deletion for any app that
    // supports account creation, not just a sign-out.
    private func deleteAccount() {
        guard let userId = authService.currentUser?.id else { return }

        if let ownedMucks = try? modelContext.fetch(FetchDescriptor<Muck>(predicate: #Predicate { $0.ownerId == userId })) {
            ownedMucks.forEach { modelContext.delete($0) }
        }
        if let ownedEvents = try? modelContext.fetch(FetchDescriptor<MuckEvent>(predicate: #Predicate { $0.ownerId == userId })) {
            ownedEvents.forEach { modelContext.delete($0) }
        }
        try? modelContext.save()

        authService.signOut()
        dismiss()
    }
}
