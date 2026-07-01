import SwiftUI
import SwiftData
import Combine

@MainActor
final class MuckViewModel: ObservableObject {
    @Published var sortOrder: MuckSortOrder = .votes
    @Published var typeFilter: MuckType? = nil
    @Published var searchText: String = ""
    @Published var points: Int = 0

    private let storage = StorageService.shared
    var userId: String = AppUser.guest.id

    init() {
        points = storage.loadPoints(for: userId)
    }

    // MARK: - Filtering & Sorting

    func filtered(_ mucks: [Muck]) -> [Muck] {
        var result = mucks.filter { !$0.isClosed }

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
        storage.addPoints(action.value, for: userId)
        points = storage.loadPoints(for: userId)
        storage.recordActivityToday(for: userId)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
