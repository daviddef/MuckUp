import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allMucks: [Muck]

    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService

    @State private var showRaiseMuck = false
    @State private var selectedMuck: Muck? = nil

    private var mucks: [Muck] { muckVM.filtered(allMucks) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.muckBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter + sort bar
                    filterBar

                    // List
                    if mucks.isEmpty {
                        emptyState
                    } else {
                        muckList
                    }
                }

                // Floating action button
                fab
            }
            .navigationTitle("")
            .toolbar { toolbar }
            .sheet(isPresented: $showRaiseMuck) {
                RaiseMuckView()
            }
            .navigationDestination(item: $selectedMuck) { muck in
                ViewMuckView(muck: muck)
            }
        }
    }

    // MARK: - Sub-views

    private var filterBar: some View {
        VStack(spacing: Spacing.xs) {
            TypeFilterBar(selection: $muckVM.typeFilter)

            // Sort toggle
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(MuckSortOrder.allCases, id: \.self) { order in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                muckVM.sortOrder = order
                            }
                        } label: {
                            Text(order.displayName)
                                .font(.muckCaption)
                                .foregroundStyle(muckVM.sortOrder == order ? .white : .muckNearBlack.opacity(0.6))
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xxs + 2)
                                .background(muckVM.sortOrder == order ? Color.muckNearBlack : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.muckSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.muckNearBlack.opacity(0.1), lineWidth: 1)
                )
                .padding(.trailing, Spacing.md)
            }
        }
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
        .background(Color.muckBg)
    }

    private var muckList: some View {
        List {
            ForEach(mucks) { muck in
                MuckCardView(
                    muck: muck,
                    hasVoted: !muckVM.canVote(muck),
                    onVote: { muckVM.upvote(muck) },
                    userLocation: locationService.location
                )
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onTapGesture { selectedMuck = muck }
            }
        }
        .listStyle(.plain)
        .refreshable {
            // Refresh hook — live data fetch will go here
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "leaf.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.muckGreen.opacity(0.4))
            Text("No mucks here")
                .font(.muckTitle)
                .foregroundStyle(Color.muckNearBlack)
            Text(muckVM.typeFilter != nil ? "Try removing the filter." : "Be the first to report an issue in your area.")
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Spacing.xl)
    }

    private var fab: some View {
        Button {
            showRaiseMuck = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.muckGreen)
                .clipShape(Circle())
                .muckFloatShadow()
        }
        .padding(.trailing, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .accessibilityLabel("Raise a Muck")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Text("GRUB")
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            NavigationLink(destination: MapViewScreen()) {
                Image(systemName: "map")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.muckNearBlack)
            }

            // Points badge
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("\(muckVM.points)")
                    .font(.muckCaption)
                    .monospacedDigit()
            }
            .foregroundStyle(Color.muckAmber)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background(Color.muckAmber.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(previewContainer)
        .environmentObject(MuckViewModel())
        .environmentObject(LocationService())
}
