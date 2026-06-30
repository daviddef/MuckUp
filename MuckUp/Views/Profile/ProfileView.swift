import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var allMucks: [Muck]
    @Query private var allEvents: [MuckEvent]
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var eventVM: EventViewModel

    @State private var selectedTab = 0

    private var myMucks: [Muck] { allMucks.filter { _ in true } } // All for now — filter by userId when auth added
    private var favMucks: [Muck] {
        let ids = StorageService.shared.loadFavouriteMucks(for: muckVM.userId)
        return allMucks.filter { ids.contains($0.id) }
    }
    private var favEvents: [MuckEvent] {
        let ids = StorageService.shared.loadFavouriteEvents(for: eventVM.userId)
        return allEvents.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Points hero
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Muck Points")
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(Color.muckAmber)
                            Text("\(muckVM.points)")
                                .font(.muckDisplay)
                                .foregroundStyle(Color.muckNearBlack)
                        }
                    }
                    Spacer()
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.muckNearBlack.opacity(0.2))
                }
                .padding(Spacing.md)
                .background(Color.muckSurface)

                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("My Mucks").tag(0)
                    Text("⭐ Mucks").tag(1)
                    Text("⭐ Events").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                TabView(selection: $selectedTab) {
                    muckListTab(mucks: myMucks, emptyText: "You haven't raised any mucks yet.").tag(0)
                    muckListTab(mucks: favMucks, emptyText: "No saved mucks yet.").tag(1)
                    eventListTab(events: favEvents).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.muckBg)
            .navigationTitle("My Profile")
        }
    }

    @ViewBuilder
    private func muckListTab(mucks: [Muck], emptyText: String) -> some View {
        if mucks.isEmpty {
            VStack {
                Spacer()
                Text(emptyText)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                Spacer()
            }
        } else {
            List {
                ForEach(mucks) { muck in
                    MuckCardView(muck: muck, hasVoted: !muckVM.canVote(muck), onVote: {})
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                }
                .onDelete { indexSet in
                    // Remove from favourites
                    for i in indexSet {
                        let id = mucks[i].id
                        muckVM.toggleFavourite(muckId: id)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func eventListTab(events: [MuckEvent]) -> some View {
        if events.isEmpty {
            VStack {
                Spacer()
                Text("No saved events yet.")
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                Spacer()
            }
        } else {
            List(events) { event in
                EventRowView(event: event)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
            }
            .listStyle(.plain)
        }
    }
}
