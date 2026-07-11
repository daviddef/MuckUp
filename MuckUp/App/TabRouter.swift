import SwiftUI

/// Shared tab selection so sheets presented from any tab (e.g. Raise a
/// Muck from the Help tab) can genuinely navigate back to Home instead of
/// just dismissing themselves and leaving the user wherever they were.
@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab = 0

    func goHome() {
        selectedTab = 0
    }
}
