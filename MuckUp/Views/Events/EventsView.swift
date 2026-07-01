import SwiftUI
import SwiftData

struct EventsView: View {
    @Query(sort: \MuckEvent.eventDate) private var allEvents: [MuckEvent]
    @EnvironmentObject var eventVM: EventViewModel
    @State private var showSchedule = false

    private var upcomingEvents: [MuckEvent] { allEvents.filter { !$0.isPast } }
    private var pastEvents: [MuckEvent]    { allEvents.filter { $0.isPast  } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $eventVM.showAttendingOnly) {
                    Text("All Events").tag(false)
                    Text("Attending").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                let filtered = eventVM.filtered(allEvents)
                if filtered.isEmpty {
                    Spacer()
                    Text(eventVM.showAttendingOnly ? "You're not attending any events yet." : "No events yet.")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    Spacer()
                } else {
                    List {
                        let upcoming = filtered.filter { !$0.isPast }
                        let past     = filtered.filter { $0.isPast  }

                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcoming) { event in
                                    NavigationLink(destination: eventDestination(event)) {
                                        EventRowView(event: event)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                                }
                            }
                        }

                        if !past.isEmpty {
                            Section("Past") {
                                ForEach(past) { event in
                                    NavigationLink(destination: EventWrapUpView(event: event)) {
                                        EventRowView(event: event)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                                    .opacity(0.5)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.muckBg)
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSchedule = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.muckGreen)
                    }
                }
            }
            .sheet(isPresented: $showSchedule) {
                ScheduleEventView()
            }
        }
    }

    @ViewBuilder
    private func eventDestination(_ event: MuckEvent) -> some View {
        if event.isToday || event.isLive {
            EventLiveView(event: event)
        } else {
            EventDetailView(event: event)
        }
    }
}

// MARK: - Event Detail (pre-event)

struct EventDetailView: View {
    @Bindable var event: MuckEvent
    @State private var attending: Bool
    @Query private var allMucks: [Muck]
    @EnvironmentObject var eventVM: EventViewModel

    init(event: MuckEvent) {
        self.event = event
        _attending = State(initialValue: event.isAttending)
    }

    private var linkedMucks: [Muck] {
        allMucks.filter { event.muckIds.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Date + location
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Label(event.eventDate.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckAmber)
                    Label(event.location, systemImage: "mappin.circle.fill")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                }

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.8))
                }

                Divider()

                // Stats
                HStack {
                    Label("\(event.participants) going", systemImage: "person.2.fill")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                    Spacer()
                    Label("\(linkedMucks.count) mucks", systemImage: "mappin.fill")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                }

                // RSVP
                Button {
                    attending.toggle()
                    event.isAttending = attending
                    if attending {
                        event.participants += 1
                        NotificationService.shared.scheduleEventReminders(for: event)
                        eventVM.recordAttended(event.id)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } else {
                        event.participants = max(0, event.participants - 1)
                        NotificationService.shared.cancelEventReminders(for: event.id)
                    }
                } label: {
                    Label(attending ? "You're going!" : "RSVP — I'm In",
                          systemImage: attending ? "checkmark.circle.fill" : "hand.raised.fill")
                        .font(.muckHeadline)
                        .foregroundStyle(attending ? Color.muckGreen : .white)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                        .background(attending ? Color.muckGreen.opacity(0.12) : Color.muckGreen)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)

                // Linked mucks
                if !linkedMucks.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Mucks to tackle")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        ForEach(linkedMucks) { muck in
                            HStack {
                                TypeBadgeView(type: muck.type, compact: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(muck.location)
                                        .font(.muckHeadline)
                                        .foregroundStyle(Color.muckNearBlack)
                                    Text(muck.muckDescription)
                                        .font(.muckBody)
                                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Label("\(muck.votes)", systemImage: "arrow.up")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                            }
                            .padding(Spacing.sm)
                            .background(Color.muckSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.muckBg)
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Event Row

struct EventRowView: View {
    let event: MuckEvent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(event.title)
                    .font(.muckTitle)
                    .foregroundStyle(Color.muckNearBlack)
                Spacer()
                if event.isAttending {
                    Label("Going", systemImage: "checkmark.circle.fill")
                        .font(.muckMicro)
                        .foregroundStyle(Color.muckGreen)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(Color.muckGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                if event.isToday || event.isLive {
                    Text(event.isLive ? "LIVE" : "TODAY")
                        .font(.muckMicro)
                        .foregroundStyle(event.isLive ? .white : Color.muckAmber)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(event.isLive ? Color.muckRed : Color.muckAmber.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            HStack {
                Label(event.location, systemImage: "mappin")
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                    .lineLimit(1)
                Spacer()
                Label("\(event.participants)", systemImage: "person.2")
                    .font(.muckCaption)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }
            Text(event.eventDate, style: .date)
                .font(.muckCaption)
                .foregroundStyle(Color.muckAmber)
        }
        .padding(Spacing.md)
        .background(event.isAttending ? Color.muckGreen.opacity(0.06) : Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(event.isAttending ? Color.muckGreen.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .muckCardShadow()
    }
}
