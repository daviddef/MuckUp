import SwiftUI
import SwiftData
import Combine

@MainActor
final class MuckViewModel: ObservableObject {
    @Published var sortOrder: MuckSortOrder = .date
    @Published var typeFilter: MuckType? = nil
    @Published var searchText: String = ""
    @Published var points: Int = 0
    // Set the moment points cross into a new rank; views observe this to
    // show a celebratory rank-up moment, then clear it back to nil.
    @Published var justRankedUp: MuckRank? = nil

    var rank: MuckRank { MuckRank.forPoints(points) }

    // Light-touch Junior Mode — fuzzes the displayed map position and
    // trims raised-muck locations to suburb level. No guardian-account
    // system yet; any user can opt in from Profile.
    @Published var isJuniorMode: Bool = false {
        didSet {
            guard isJuniorMode != oldValue else { return }
            storage.setJuniorMode(isJuniorMode, for: userId)
        }
    }

    private let storage = StorageService.shared
    var userId: String = AppUser.guest.id
    // Set once at app launch so every awarded point also lands on the
    // user's squad total, without MuckViewModel needing to know
    // SquadViewModel exists.
    var onAward: ((Int) -> Void)?

    init() {
        points = storage.loadPoints(for: userId)
        isJuniorMode = storage.isJuniorMode(for: userId)
    }

    /// Called once the real signed-in (or guest) user is known — swaps the
    /// working userId and reloads whatever was already stored under it.
    func updateUser(_ newUserId: String) {
        guard newUserId != userId else { return }
        userId = newUserId
        points = storage.loadPoints(for: userId)
        isJuniorMode = storage.isJuniorMode(for: userId)
        objectWillChange.send()
    }

    // MARK: - Filtering & Sorting

    func filtered(_ mucks: [Muck]) -> [Muck] {
        var result = mucks.filter { !$0.isClosed && !$0.isHiddenByFlags }

        if let filter = typeFilter {
            result = result.filter { $0.type == filter }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.location.lowercased().contains(q) ||
                $0.muckDescription.lowercased().contains(q)
            }
        }

        switch sortOrder {
        case .votes: result.sort { $0.votes > $1.votes }
        case .date:  result.sort { $0.reportedDate > $1.reportedDate }
        }

        return result
    }

    // MARK: - Voting

    func canVote(_ muck: Muck) -> Bool {
        !storage.hasVoted(muckId: muck.id, userId: userId)
    }

    func upvote(_ muck: Muck) {
        guard canVote(muck) else { return }
        muck.votes += 1
        storage.recordVoteLocally(muckId: muck.id, userId: userId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Moderation

    func canFlag(_ muck: Muck) -> Bool {
        !storage.hasFlagged(muckId: muck.id, userId: userId)
    }

    /// Records the flag locally (so this device only flags once) and
    /// bumps the muck's own count so it disappears from this device
    /// immediately, while pushing the increment to the shared database
    /// in the background so other users see the same thing.
    func flag(_ muck: Muck) {
        guard canFlag(muck) else { return }
        storage.recordFlagLocally(muckId: muck.id, userId: userId)
        muck.flagCount += 1
        Task { await CloudKitMuckSyncService.shared.flag(muckId: muck.id) }
    }

    // MARK: - Favourites

    func isFavourite(muckId: String) -> Bool {
        storage.loadFavouriteMucks(for: userId).contains(muckId)
    }

    func toggleFavourite(muckId: String) {
        var favs = storage.loadFavouriteMucks(for: userId)
        if let idx = favs.firstIndex(of: muckId) {
            favs.remove(at: idx)
        } else {
            favs.append(muckId)
        }
        storage.saveFavouriteMucks(favs, for: userId)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        objectWillChange.send()
    }

    // MARK: - Points

    func award(_ action: PointAction) {
        let previousRank = rank
        storage.addPoints(action.value, for: userId)
        points = storage.loadPoints(for: userId)
        storage.recordActivityToday(for: userId)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onAward?(action.value)

        if rank > previousRank {
            justRankedUp = rank
        }
    }

    // MARK: - Personal history

    func recordRaised(_ muckId: String) {
        storage.recordRaisedMuck(muckId, for: userId)
    }

    func recordClosed(_ muckId: String) {
        storage.recordClosedMuck(muckId, for: userId)
    }

    var raisedMuckIds: [String] { storage.loadRaisedMuckIds(for: userId) }
    var closedMuckIds: [String] { storage.loadClosedMuckIds(for: userId) }
    var streak: Int { storage.currentStreak(for: userId) }

    // MARK: - Personal history (Help Me)

    func recordHelpPosted(_ id: String) {
        storage.recordPostedHelpRequest(id, for: userId)
    }

    func recordHelpOffered(_ id: String) {
        storage.recordOfferedHelp(id, for: userId)
    }

    func recordHelpCompleted(_ id: String) {
        storage.recordCompletedHelp(id, for: userId)
    }

    var postedHelpRequestIds: [String] { storage.loadPostedHelpRequestIds(for: userId) }
    var offeredHelpIds: [String] { storage.loadOfferedHelpIds(for: userId) }
    var completedHelpIds: [String] { storage.loadCompletedHelpIds(for: userId) }
}
