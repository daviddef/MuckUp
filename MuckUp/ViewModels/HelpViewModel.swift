import SwiftUI
import CoreLocation

@MainActor
final class HelpViewModel: ObservableObject {
    @Published var categoryFilter: HelpCategory? = nil
    @Published var showMineOnly = false

    private let storage = StorageService.shared
    var userId: String = AppUser.guest.id

    func filtered(_ requests: [HelpRequest]) -> [HelpRequest] {
        var result = requests.filter { $0.status != .completed }

        if showMineOnly {
            let mine = Set(storage.loadPostedHelpRequestIds(for: userId))
            result = result.filter { mine.contains($0.id) }
        }

        if let categoryFilter {
            result = result.filter { $0.category == categoryFilter }
        }

        return result.sorted { $0.preferredDate < $1.preferredDate }
    }

    func hasOffered(_ request: HelpRequest) -> Bool {
        request.helperIds.contains(userId)
    }

    func isMine(_ request: HelpRequest) -> Bool {
        request.requesterId == userId
    }

    func offerHelp(_ request: HelpRequest) -> Bool {
        guard !hasOffered(request), !isMine(request) else { return false }
        request.helperIds.append(userId)
        if request.status == .open {
            request.status = .matched
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    func markCompleted(_ request: HelpRequest) {
        request.status = .completed
    }
}
