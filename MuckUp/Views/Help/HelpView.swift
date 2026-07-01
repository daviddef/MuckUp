import SwiftUI
import SwiftData
import CoreLocation

enum HelpLane: String, CaseIterable {
    case helpWorld, helpMe

    var title: String {
        switch self {
        case .helpWorld: return "🌍 Help Us Cleanup"
        case .helpMe:    return "🙋 Help Me"
        }
    }
}

struct HelpView: View {
    @Query private var allMucks: [Muck]
    @Query(sort: \MuckEvent.eventDate) private var allEvents: [MuckEvent]
    @Query private var allHelpRequests: [HelpRequest]

    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var helpVM: HelpViewModel
    @EnvironmentObject var locationService: LocationService

    @State private var lane: HelpLane = .helpWorld
    @State private var showAskForHelp = false
    @State private var showRaiseMuck = false
    @State private var selectedRequest: HelpRequest?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $lane) {
                    ForEach(HelpLane.allCases, id: \.self) { l in
                        Text(l.title).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                switch lane {
                case .helpWorld: helpWorldTab
                case .helpMe:    helpMeTab
                }
            }
            .background(Color.muckBg)
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAskForHelp) {
                AskForHelpView()
            }
            .sheet(isPresented: $showRaiseMuck) {
                RaiseMuckView()
            }
            .navigationDestination(item: $selectedRequest) { request in
                HelpRequestDetailView(request: request)
            }
        }
    }

    // MARK: - Help the World (environmental impact launcher)

    private var openMuckCount: Int { muckVM.filtered(allMucks).count }
    private var upcomingEventCount: Int { allEvents.filter { !$0.isPast }.count }

    private var helpWorldTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Do something for your neighbourhood")
                        .font(.muckDisplay)
                        .foregroundStyle(Color.muckNearBlack)
                    Text("Spot litter, report a hazard, or join a community cleanup near you.")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }

                HStack(spacing: Spacing.sm) {
                    HelpStatCard(icon: "mappin.circle.fill", value: "\(openMuckCount)", label: "open mucks nearby")
                    HelpStatCard(icon: "calendar", value: "\(upcomingEventCount)", label: "upcoming events")
                }

                VStack(spacing: Spacing.sm) {
                    HelpLaneActionRow(
                        icon: "leaf.fill",
                        title: "Raise a Muck",
                        subtitle: "Report litter, a hazard, or something that needs fixing.",
                        color: Color.muckGreen
                    ) {
                        showRaiseMuck = true
                    }

                    NavigationLink {
                        MapViewScreen()
                    } label: {
                        HelpLaneActionRow(
                            icon: "map.fill",
                            title: "Browse the Map",
                            subtitle: "See every open muck and event around you.",
                            color: Color.muckAmber,
                            isLink: true
                        ) {}
                    }
                    .buttonStyle(.plain)
                }

                Text("🤝 Prefer to help a person instead?")
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                    .padding(.top, Spacing.sm)

                Button {
                    withAnimation { lane = .helpMe }
                } label: {
                    HelpLaneActionRow(
                        icon: "hand.raised.fill",
                        title: "Switch to Help Me",
                        subtitle: "Browse requests from neighbours who need a hand.",
                        color: Color.helpCategoryColor(.other),
                        isLink: true
                    ) {}
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Help Me (personal request feed)

    private var helpMeTab: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    FilterPill(title: "All", isActive: helpVM.categoryFilter == nil) {
                        helpVM.categoryFilter = nil
                    }
                    ForEach(HelpCategory.allCases, id: \.self) { cat in
                        FilterPill(
                            title: cat.displayName,
                            isActive: helpVM.categoryFilter == cat,
                            activeColor: Color.helpCategoryColor(cat)
                        ) {
                            helpVM.categoryFilter = (helpVM.categoryFilter == cat) ? nil : cat
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.xs)

            let requests = helpVM.filtered(allHelpRequests)

            if requests.isEmpty {
                Spacer()
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.muckNearBlack.opacity(0.2))
                    Text("No open requests nearby")
                        .font(.muckTitle)
                        .foregroundStyle(Color.muckNearBlack)
                    Text("Be the first to ask your neighbours for a hand.")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }
                .padding(Spacing.xl)
                Spacer()
            } else {
                List(requests) { request in
                    HelpRequestCard(
                        request: request,
                        distance: request.distanceLabel(from: locationService.location),
                        hasOffered: helpVM.hasOffered(request)
                    )
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onTapGesture { selectedRequest = request }
                }
                .listStyle(.plain)
            }

            PrimaryButton(title: "Ask for Help", icon: "hand.raised.fill") {
                showAskForHelp = true
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - Stat card

private struct HelpStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.muckGreen)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.muckNearBlack)
            Text(label)
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

// MARK: - Action row

private struct HelpLaneActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isLink: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle().fill(color.opacity(0.12)).frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack)
                    Text(subtitle)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.muckNearBlack.opacity(0.25))
            }
            .padding(Spacing.sm)
            .background(Color.muckSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(isLink)
    }
}
