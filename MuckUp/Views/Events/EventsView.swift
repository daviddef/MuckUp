import SwiftUI
import SwiftData

struct EventsView: View {
    @Query private var allEvents: [MuckEvent]
    @EnvironmentObject var eventVM: EventViewModel
    @State private var showSchedule = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Attending toggle
                Picker("", selection: $eventVM.showAttendingOnly) {
                    Text("All Events").tag(false)
                    Text("Attending").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                let events = eventVM.filtered(allEvents)
                if events.isEmpty {
                    Spacer()
                    Text(eventVM.showAttendingOnly ? "You're not attending any events yet." : "No events yet.")
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    Spacer()
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
            .background(Color.muckBg)
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSchedule = true
                    } label: {
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
}

struct EventRowView: View {
    let event: MuckEvent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(event.title)
                .font(.muckTitle)
                .foregroundStyle(Color.muckNearBlack)
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
        .background(Color.muckSurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .muckCardShadow()
    }
}
