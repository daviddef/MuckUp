import SwiftUI
import SwiftData

struct RaiseMuckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService

    @State private var selectedType: MuckType = .cleanup
    @State private var description = ""
    @State private var isHazardous = false
    @State private var reportedDate = Date.now
    @State private var isSaved = false

    private var isValid: Bool { description.trimmingCharacters(in: .whitespaces).count >= 10 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {

                    // Type selector
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("What type of muck is this?")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)

                        HStack(spacing: Spacing.sm) {
                            ForEach(MuckType.allCases, id: \.self) { type in
                                TypeSelectorCard(type: type, isSelected: selectedType == type) {
                                    selectedType = type
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }

                    // Hazardous toggle
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Toggle(isOn: $isHazardous) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(isHazardous ? Color.muckRed : Color.muckNearBlack.opacity(0.4))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Mark as Hazardous")
                                        .font(.muckHeadline)
                                        .foregroundStyle(Color.muckNearBlack)
                                    Text("Chemical, biological, or dangerous to approach")
                                        .font(.muckCaption)
                                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                                }
                            }
                        }
                        .tint(Color.muckRed)
                        .padding(Spacing.sm)
                        .background(isHazardous ? Color.muckRed.opacity(0.06) : Color.muckSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Describe the issue")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        TextEditor(text: $description)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack)
                            .frame(minHeight: 100)
                            .padding(Spacing.sm)
                            .background(Color.muckSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .strokeBorder(Color.muckNearBlack.opacity(0.1))
                            )
                        if description.count < 10 && !description.isEmpty {
                            Text("Please add a bit more detail (at least 10 characters)")
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckRed)
                        }
                    }

                    // Date
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("When did you notice this?")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        DatePicker("", selection: $reportedDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(Color.muckGreen)
                    }

                    // Photo placeholder
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Add a photo")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        Button {
                            // Camera/photo sheet will go here
                        } label: {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                Text("Take or choose a photo")
                                    .font(.muckHeadline)
                            }
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.lg)
                            .background(Color.muckSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    PrimaryButton(
                        title: "Submit Muck",
                        icon: "checkmark",
                        isDisabled: !isValid
                    ) {
                        submitMuck()
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.md)
            }
            .background(Color.muckBg)
            .navigationTitle("Raise a Muck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
            .navigationDestination(isPresented: $isSaved) {
                MuckSavedView()
            }
        }
    }

    private func submitMuck() {
        let newMuck = Muck(
            location: locationService.locationName,
            description: description,
            type: selectedType,
            isHazardous: isHazardous,
            reportedDate: reportedDate,
            latitude: locationService.location?.coordinate.latitude ?? -37.8136,
            longitude: locationService.location?.coordinate.longitude ?? 144.9631
        )
        modelContext.insert(newMuck)
        muckVM.award(.raiseMuck)
        isSaved = true
    }
}

// MARK: - Type Selector Card

private struct TypeSelectorCard: View {
    let type: MuckType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Color.muckTypeColor(type))
                Text(type.displayName)
                    .font(.muckCaption)
                    .foregroundStyle(isSelected ? .white : .muckNearBlack)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? Color.muckTypeColor(type) : Color.muckSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(isSelected ? Color.clear : Color.muckNearBlack.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Muck Saved

struct MuckSavedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showScheduleEvent = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.muckGreen)
            Text("Muck Raised!")
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
            Text("+1 Muck Point earned")
                .font(.muckHeadline)
                .foregroundStyle(Color.muckAmber)
            Spacer()
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Schedule a Community Event", icon: "calendar.badge.plus") {
                    showScheduleEvent = true
                }
                SecondaryButton(title: "Back to Home") {
                    // Pop to root
                    dismiss()
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.muckBg.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showScheduleEvent) {
            ScheduleEventView(preselectedMuck: nil)
        }
    }
}

#Preview {
    RaiseMuckView()
        .modelContainer(previewContainer)
        .environmentObject(MuckViewModel())
        .environmentObject(LocationService())
}
