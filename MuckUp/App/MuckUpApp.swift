import SwiftUI
import SwiftData

@main
struct MuckUpApp: App {
    @StateObject private var muckVM = MuckViewModel()
    @StateObject private var eventVM = EventViewModel()
    @StateObject private var partnerVM = PartnerViewModel()
    @StateObject private var helpVM = HelpViewModel()
    @StateObject private var authService = AuthService()
    @StateObject private var locationService = LocationService()
    @StateObject private var awarenessVM = AwarenessViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(muckVM)
                .environmentObject(eventVM)
                .environmentObject(partnerVM)
                .environmentObject(helpVM)
                .environmentObject(authService)
                .environmentObject(locationService)
                .environmentObject(awarenessVM)
                .onAppear {
                    locationService.requestLocation()
                    NotificationService.shared.requestPermission()
                }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    /// Tries to open a CloudKit-synced private-database container first —
    /// this requires the iCloud capability + a CloudKit container to be
    /// enabled in Signing & Capabilities (Xcode) and the Apple Developer
    /// portal. If that isn't set up yet (or the simulator has no iCloud
    /// account signed in), falls back to a plain local store so the app
    /// still runs — it just won't sync until CloudKit is provisioned.
    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Muck.self, MuckEvent.self, HelpRequest.self])
        do {
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("⚠️ CloudKit-backed storage unavailable (\(error.localizedDescription)). Falling back to local-only storage. Enable iCloud + CloudKit in Signing & Capabilities to sync across devices.")
            let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            guard let container = try? ModelContainer(for: schema, configurations: [localConfig]) else {
                fatalError("Failed to create even a local-only ModelContainer.")
            }
            return container
        }
    }()
}
