import SwiftUI

struct ContentView: View {
    @EnvironmentObject var muckVM: MuckViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            FindView()
                .tabItem {
                    Label("Find", systemImage: selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                }
                .tag(1)

            EventsView()
                .tabItem {
                    Label("Events", systemImage: selectedTab == 2 ? "calendar.circle.fill" : "calendar.circle")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 3 ? "person.circle.fill" : "person.circle")
                }
                .tag(3)
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
        .environmentObject(LocationService())
}
