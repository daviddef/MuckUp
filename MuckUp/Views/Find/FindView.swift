import SwiftUI

struct FindView: View {
    @EnvironmentObject var partnerVM: PartnerViewModel
    @EnvironmentObject var locationService: LocationService
    @State private var searchText = ""

    private var filteredItems: [PartnerItem] {
        let base = partnerVM.filteredItems
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q) ||
            ($0.itemDescription?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Source filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        FilterPill(title: "All", isActive: partnerVM.sourceFilter == nil) {
                            partnerVM.sourceFilter = nil
                        }
                        ForEach(PartnerSource.allCases) { source in
                            FilterPill(
                                title: source.displayName,
                                isActive: partnerVM.sourceFilter == source,
                                activeColor: Color.partnerColor(source)
                            ) {
                                partnerVM.sourceFilter = (partnerVM.sourceFilter == source) ? nil : source
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .padding(.vertical, Spacing.xs)

                if partnerVM.isLoading {
                    Spacer()
                    ProgressView("Finding nearby activity…")
                        .tint(Color.muckGreen)
                    Spacer()
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            PartnerItemRow(item: item)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                        }

                        // More Organisations footer
                        Section {
                            MoreOrganisationsView()
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search nearby activity")
                }
            }
            .background(Color.muckBg)
            .navigationTitle("Find")
            .task {
                if partnerVM.items.isEmpty {
                    if let loc = locationService.location {
                        await partnerVM.fetchAll(near: loc)
                    } else {
                        partnerVM.loadMockData()
                    }
                }
            }
        }
    }
}

struct PartnerItemRow: View {
    let item: PartnerItem
    @State private var showSafari = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                SourceBadgeView(source: item.source)
                if let emoji = item.weatherEmoji {
                    Text(emoji)
                        .font(.muckCaption)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.muckSurface)
                        .clipShape(Capsule())
                }
                Spacer()
                if let date = item.displayDate {
                    Text(date)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                }
            }

            Text(item.name)
                .font(.muckTitle)
                .foregroundStyle(Color.muckNearBlack)

            if let desc = item.itemDescription {
                Text(desc)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.65))
                    .lineLimit(2)
            }

            if let attendees = item.attendees {
                Label("\(attendees) attending", systemImage: "person.2")
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }

            // CTA
            if item.source.promptsCreateMuck {
                HStack {
                    SecondaryButton(title: "🌿  Create a Muck", action: {})
                    Spacer()
                    Link("View on \(item.source.displayName) →", destination: item.externalURL)
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                }
            } else {
                Link("Join on TrashMob →", destination: item.externalURL)
                    .font(.muckCaption)
                    .foregroundStyle(Color.partnerColor(item.source))
            }
        }
        .padding(Spacing.md)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
    }
}

struct MoreOrganisationsView: View {
    let orgs: [(name: String, url: URL)] = [
        ("Keep Australia Beautiful", URL(string: "https://www.kab.org.au")!),
        ("Clean Up Australia", URL(string: "https://www.cleanup.org.au")!),
        ("OzGREEN", URL(string: "https://www.ozgreen.org.au")!),
        ("Tangaroa Blue", URL(string: "https://www.tangaroablue.org")!),
        ("Planet Ark", URL(string: "https://planetark.org")!),
        ("Landcare Australia", URL(string: "https://landcareaustralia.org.au")!),
        ("Bush Heritage", URL(string: "https://www.bushheritage.org.au")!),
        ("Greening Australia", URL(string: "https://www.greeningaustralia.org.au")!),
        ("Australian Conservation Foundation", URL(string: "https://www.acf.org.au")!),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("More Organisations")
                .font(.muckTitle)
                .foregroundStyle(Color.muckNearBlack)
                .padding(.bottom, Spacing.xxs)
            ForEach(orgs, id: \.name) { org in
                Link(destination: org.url) {
                    HStack {
                        Text(org.name)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.muckNearBlack.opacity(0.3))
                    }
                    .padding(.vertical, Spacing.xxs)
                }
                Divider()
            }
        }
        .padding(Spacing.md)
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}
