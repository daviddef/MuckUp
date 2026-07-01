import SwiftUI
import SwiftData

@main
struct MuckUpApp: App {
    @StateObject private var muckVM = MuckViewModel()
    @StateObject private var eventVM = EventViewModel()
    @StateObject private var partnerVM = PartnerViewModel()
    @StateObject private var helpVM = HelpViewModel()
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(muckVM)
                .environmentObject(eventVM)
                .environmentObject(partnerVM)
                .environmentObject(helpVM)
                .environmentObject(locationService)
                .onAppear {
                    locationService.requestLocation()
                    NotificationService.shared.requestPermission()
                }
        }
        .modelContainer(for: [Muck.self, MuckEvent.self, HelpRequest.self])
    }
}
