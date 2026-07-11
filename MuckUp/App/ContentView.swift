import SwiftUI

struct ContentView: View {
    @EnvironmentObject var muckVM: MuckViewModel
    @StateObject private var tabRouter = TabRouter()

    var body: some View {
        ZStack(alignment: .top) {
            tabView
                .environmentObject(tabRouter)

            if let rank = muckVM.justRankedUp {
                RankUpBanner(rank: rank) {
                    muckVM.justRankedUp = nil
                }
                .zIndex(1)
                .transition(.identity)
            }
        }
    }

    private var tabView: some View {
        TabView(selection: $tabRouter.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: tabRouter.selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            FindView()
                .tabItem {
                    Label("Find", systemImage: tabRouter.selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                }
                .tag(1)

            HelpView()
                .tabItem {
                    Label("Help", systemImage: tabRouter.selectedTab == 2 ? "hand.raised.fill" : "hand.raised")
                }
                .tag(2)

            EventsView()
                .tabItem {
                    Label("Events", systemImage: tabRouter.selectedTab == 3 ? "calendar.circle.fill" : "calendar.circle")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: tabRouter.selectedTab == 4 ? "person.circle.fill" : "person.circle")
                }
                .tag(4)
        }
        .tint(Color.muckGreen)
    }
}

#Preview {
    ContentView()
        .modelContainer(previewContainer)
        .environmentObject(MuckViewModel())
        .environmentObject(EventViewModel())
        .environmentObject(PartnerViewModel())
        .environmentObject(HelpViewModel())
        .environmentObject(LocationService())
        .environmentObject(AwarenessViewModel())
}
