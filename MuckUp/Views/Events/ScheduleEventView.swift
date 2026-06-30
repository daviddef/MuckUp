import SwiftUI
import SwiftData

struct ScheduleEventView: View {
    var preselectedMuck: Muck?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @Query private var allMucks: [Muck]

    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedMuckIds: Set<String> = []
    @State private var isSaved = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !selectedMuckIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // Muck selector
                Section {
                    ForEach(allMucks.filter { !$0.isClosed && $0.type.allowsEvents }) { muck in
                        Button {
                            if selectedMuckIds.contains(muck.id) {
                                selectedMuckIds.remove(muck.id)
                            } else {
                                selectedMuckIds.insert(muck.id)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedMuckIds.contains(muck.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedMuckIds.contains(muck.id) ? Color.muckGreen : Color.muckNearBlack.opacity(0.3))
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
                                TypeBadgeView(type: muck.type, compact: true)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Select Mucks")
                        .font(.muckCaption)
                }

                // Title
                Section {
                    TextField("e.g. Princes Park Saturday Blitz", text: $title)
                        .font(.muckBody)
                } header: {
                    Text("Event Title *")
                        .font(.muckCaption)
                }

                // Description
                Section {
                    TextEditor(text: $description)
                        .font(.muckBody)
                        .frame(minHeight: 80)
                } header: {
                    Text("Description")
                        .font(.muckCaption)
                }

                // Date
                Section {
                    DatePicker("Date & Time", selection: $eventDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                        .tint(Color.muckGreen)
                } header: {
                    Text("When")
                        .font(.muckCaption)
                }

                // Submit
                Section {
                    PrimaryButton(title: "Create Event", icon: "calendar.badge.plus", isDisabled: !isValid) {
                        createEvent()
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Schedule Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
            .navigationDestination(isPresented: $isSaved) {
                EventSavedView()
            }
        }
        .onAppear {
            if let muck = preselectedMuck {
                selectedMuckIds.insert(muck.id)
            }
        }
    }

    private func createEvent() {
        let event = MuckEvent(
            title: title,
            location: allMucks.first(where: { selectedMuckIds.contains($0.id) })?.location ?? "",
            date: eventDate,
            description: description,
            muckIds: Array(selectedMuckIds),
            participants: 1,
            isAttending: true
        )
        modelContext.insert(event)
        // Increment eventCount on linked mucks
        for id in selectedMuckIds {
            allMucks.first(where: { $0.id == id })?.eventCount += 1
        }
        muckVM.award(.participate)
        isSaved = true
    }
}

struct EventSavedView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 72))
                .foregroundStyle(Color.muckGreen)
            Text("Event Scheduled!")
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
            Text("+5 Muck Points earned")
                .font(.muckHeadline)
                .foregroundStyle(Color.muckAmber)
            Text("Confirmation and details will be sent to your registered email.")
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            PrimaryButton(title: "Back to Home") {
                dismiss()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.muckBg.ignoresSafeArea())
        .navigationBarBackButtonHidden()
    }
}
