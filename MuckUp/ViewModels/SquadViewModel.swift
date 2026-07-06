import SwiftUI

@MainActor
final class SquadViewModel: ObservableObject {
    @Published var squadName: String? = nil
    @Published var squadCode: String? = nil
    @Published var totalPoints: Int = 0
    @Published var memberCount: Int = 1
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var leaderboard: [CloudKitSquadSyncService.SquadInfo] = []

    private let storage = StorageService.shared
    private let sync = CloudKitSquadSyncService.shared
    var userId: String = AppUser.guest.id

    var isInSquad: Bool { squadCode != nil }

    func loadMySquad() async {
        guard let code = storage.mySquadCode(for: userId) else { return }
        isLoading = true
        defer { isLoading = false }
        guard let info = await sync.refresh(code: code) else { return }
        apply(info)
    }

    func createSquad(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let info = await sync.create(name: trimmed) else {
            errorMessage = "Couldn't create a squad right now — check your connection and try again."
            return
        }
        storage.setMySquadCode(info.code, for: userId)
        apply(info)
    }

    func joinSquad(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let info = await sync.join(code: trimmed) else {
            errorMessage = "Couldn't find a squad with that code."
            return
        }
        storage.setMySquadCode(info.code, for: userId)
        apply(info)
    }

    func leaveSquad() {
        storage.setMySquadCode(nil, for: userId)
        squadName = nil
        squadCode = nil
        totalPoints = 0
        memberCount = 1
    }

    /// Hooked up to MuckViewModel.onAward so every point a member earns
    /// anywhere in the app (raise, close, help) also lands on the squad's
    /// shared total — best-effort, doesn't block or fail the local award.
    func addPoints(_ amount: Int) {
        guard let code = squadCode else { return }
        totalPoints += amount
        Task { await sync.addPoints(code: code, amount: amount) }
    }

    func loadLeaderboard() async {
        leaderboard = await sync.fetchLeaderboard()
    }

    private func apply(_ info: CloudKitSquadSyncService.SquadInfo) {
        squadCode = info.code
        squadName = info.name
        totalPoints = info.totalPoints
        memberCount = info.memberCount
    }
}
