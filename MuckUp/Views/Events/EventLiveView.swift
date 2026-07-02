import SwiftUI
import SwiftData
import CoreLocation

struct EventLiveView: View {
    @Bindable var event: MuckEvent
    @Environment(\.modelContext) private var modelContext
    @Query private var allMucks: [Muck]
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var awarenessVM: AwarenessViewModel

    @State private var showWrapUp = false
    @State private var checkedIn = false
    @State private var nearbyAwarenessItems: [AwarenessItem] = []
    @State private var isLoadingAwareness = false
    @State private var selectedAwarenessItem: AwarenessItem? = nil

    private var linkedMucks: [Muck] {
        allMucks.filter { event.muckIds.contains($0.id) && !$0.isClosed }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Live header
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.muckRed)
                            .frame(width: 8, height: 8)
                            .opacity(event.isLive ? 1 : 0)
                        Text(event.isLive ? "LIVE" : "TODAY")
                            .font(.muckMicro)
                            .foregroundStyle(event.isLive ? Color.muckRed : Color.muckAmber)
                        Spacer()
                        Text(event.eventDate, style: .time)
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                    // Bag counter — the hero element
                    VStack(spacing: Spacing.sm) {
                        Text("\(event.bagCount)")
                            .font(.system(size: 80, weight: .black, design: .rounded))
                            .foregroundStyle(Color.muckGreen)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: event.bagCount)

                        Text("bags collected")
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))

                        HStack(spacing: Spacing.lg) {
                            Button {
                                if event.bagCount > 0 {
                                    event.bagCount -= 1
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.2))
                            }

                            Button {
                                event.bagCount += 1
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                // Milestone haptics
                                if event.bagCount % 10 == 0 {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 72))
                                    .foregroundStyle(Color.muckGreen)
                            }
                        }
                        .padding(.top, Spacing.xs)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                    .background(Color.muckSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .muckCardShadow()
                    .padding(.horizontal, Spacing.md)

                    // Stats row
                    HStack(spacing: 0) {
                        StatChip(value: "\(event.checkedInCount)", label: "on ground", icon: "person.fill")
                        Divider().frame(height: 36)
                        StatChip(value: "\(linkedMucks.count)", label: "mucks", icon: "mappin.fill")
                        Divider().frame(height: 36)
                        StatChip(value: estimatedKg, label: "est. kg", icon: "scalemass.fill")
                    }
                    .background(Color.muckSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .muckCardShadow()
                    .padding(.horizontal, Spacing.md)

                    // Check-in button
                    if !checkedIn {
                        Button {
                            event.checkedInCount += 1
                            checkedIn = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("Check In — I'm Here!", systemImage: "location.fill")
                                .font(.muckHeadline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.md)
                                .background(Color.muckAmber)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                        .padding(.horizontal, Spacing.md)
                    } else {
                        Label("Checked in", systemImage: "checkmark.circle.fill")
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckAmber)
                    }

                    // Mucks to tackle
                    if !linkedMucks.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Mucks to tackle")
                                .font(.muckTitle)
                                .foregroundStyle(Color.muckNearBlack)
                                .padding(.horizontal, Spacing.md)

                            ForEach(linkedMucks) { muck in
                                LiveMuckRow(muck: muck)
                                    .padding(.horizontal, Spacing.md)
                            }
                        }
                    }

                    // Things to be aware of near the meetup point
                    AwarenessListCard(
                        items: nearbyAwarenessItems,
                        isLoading: isLoadingAwareness,
                        onSelect: { selectedAwarenessItem = $0 }
                    )
                    .padding(.horizontal, Spacing.md)

                    Spacer(minLength: 100)
                }
            }
            .background(Color.muckBg)

            // Wrap up CTA
            VStack(spacing: Spacing.xs) {
                PrimaryButton(title: "Wrap Up & See Impact", icon: "chart.bar.fill") {
                    showWrapUp = true
                }
                Text("Ends the live session and generates your impact report")
                    .font(.muckMicro)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
            }
            .padding(Spacing.md)
            .background(.regularMaterial)
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !event.isLive {
                event.isLive = true
            }
        }
        .sheet(isPresented: $showWrapUp) {
            EventWrapUpView(event: event)
        }
        .sheet(item: $selectedAwarenessItem) { item in
            AwarenessDetailSheet(item: item)
        }
        .task {
            guard event.meetupLatitude != 0 || event.meetupLongitude != 0 else { return }
            isLoadingAwareness = true
            let coord = CLLocationCoordinate2D(latitude: event.meetupLatitude, longitude: event.meetupLongitude)
            nearbyAwarenessItems = await awarenessVM.fetchNearby(coord)
            isLoadingAwareness = false
        }
    }

    private var estimatedKg: String {
        // Rough estimate: 1 bag ≈ 3 kg
        let kg = event.bagCount * 3
        return "\(kg)"
    }
}

private struct StatChip: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.muckGreen)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.muckNearBlack)
            Text(label)
                .font(.muckMicro)
                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }
}

private struct LiveMuckRow: View {
    @Bindable var muck: Muck
    @EnvironmentObject var muckVM: MuckViewModel
    @State private var afterData: Data?
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(muck.location)
                            .font(.muckHeadline)
                            .foregroundStyle(muck.isClosed ? Color.muckNearBlack.opacity(0.4) : Color.muckNearBlack)
                        Text(muck.muckDescription)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                            .lineLimit(1)
                    }
                    Spacer()
                    if muck.isClosed {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.muckGreen)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.muckNearBlack.opacity(0.3))
                    }
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded && !muck.isClosed {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Divider().padding(.horizontal, Spacing.md)
                    Text("After photo")
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                        .padding(.horizontal, Spacing.md)
                    PhotoPickerButton(
                        label: "Take after photo",
                        systemImage: "camera.fill",
                        imageData: $afterData
                    )
                    .padding(.horizontal, Spacing.md)

                    Button {
                        muck.afterPhotoData = afterData
                        muck.isClosed = true
                        muck.closedDate = .now
                        muckVM.award(.closeMuck)
                        muckVM.recordClosed(muck.id)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation { isExpanded = false }
                    } label: {
                        Label("Mark Cleared", systemImage: "checkmark.seal.fill")
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckGreen)
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.sm)
                            .background(Color.muckGreen.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                }
            }
        }
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
        .opacity(muck.isClosed ? 0.5 : 1)
    }
}
