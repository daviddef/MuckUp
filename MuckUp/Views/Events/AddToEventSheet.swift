import SwiftUI
import SwiftData

struct AddToEventSheet: View {
    let muck: Muck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MuckEvent.eventDate) private var allEvents: [MuckEvent]

    @State private var added = false
    @State private var targetEvent: MuckEvent?

    private var upcomingEvents: [MuckEvent] {
        allEvents.filter { $0.eventDate >= .now && !$0.muckIds.contains(muck.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if added, let event = targetEvent {
                    // Confirmation
                    VStack(spacing: Spacing.lg) {
                        Spacer()
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.muckGreen)
                        Text("Added to Event")
                            .font(.muckDisplay)
                            .foregroundStyle(Color.muckNearBlack)
                        Text(event.title)
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                            .multilineTextAlignment(.center)
                        Spacer()
                        PrimaryButton(title: "Done") { dismiss() }
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.xl)
                    }
                } else if upcomingEvents.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.muckNearBlack.opacity(0.2))
                        Text("No upcoming events")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        Text("Schedule a new community event from the Events tab, then add this muck to it.")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                        Spacer()
                        Button("Close") { dismiss() }
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            .padding(.bottom, Spacing.xl)
                    }
                } else {
                    List(upcomingEvents) { event in
                        Button {
                            addMuck(to: event)
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(event.title)
                                    .font(.muckHeadline)
                                    .foregroundStyle(Color.muckNearBlack)
                                HStack {
                                    Label(event.location, systemImage: "mappin")
                                        .font(.muckBody)
                                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(event.eventDate, style: .date)
                                        .font(.muckCaption)
                                        .foregroundStyle(Color.muckAmber)
                                }
                                Text("\(event.muckIds.count) muck\(event.muckIds.count == 1 ? "" : "s") linked")
                                    .font(.muckMicro)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.35))
                            }
                            .padding(.vertical, Spacing.xxs)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Add to Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !added {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Color.muckNearBlack)
                    }
                }
            }
        }
    }

    private func addMuck(to event: MuckEvent) {
        guard !event.muckIds.contains(muck.id) else { return }
        event.muckIds.append(muck.id)
        muck.eventCount += 1
        targetEvent = event
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { added = true }
    }
}
