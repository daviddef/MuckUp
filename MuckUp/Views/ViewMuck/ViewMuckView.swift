import SwiftUI
import SwiftData

struct ViewMuckView: View {
    @Bindable var muck: Muck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel

    @State private var showAddToEvent = false
    @State private var isFavourite = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Type header strip
                    HStack {
                        TypeBadgeView(type: muck.type)
                        if muck.isHazardous {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("HAZARDOUS — Contact authorities")
                                    .font(.muckCaption)
                            }
                            .foregroundStyle(Color.muckRed)
                        }
                        Spacer()
                        Text(muck.id)
                            .font(.muckMicro)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.3))
                            .monospacedDigit()
                    }

                    // Location
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Label(muck.location, systemImage: "mappin.circle.fill")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        Text(muck.reportedDate, style: .date)
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    }

                    // Description
                    Text(muck.muckDescription)
                        .font(.muckBody)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.8))

                    Divider()

                    // Vote + Favourite row
                    HStack(spacing: Spacing.lg) {
                        VoteColumnView(
                            votes: muck.votes,
                            hasVoted: !muckVM.canVote(muck)
                        ) {
                            muckVM.upvote(muck)
                        }

                        Button {
                            isFavourite.toggle()
                            muckVM.toggleFavourite(muckId: muck.id)
                        } label: {
                            Label(
                                isFavourite ? "Saved" : "Save",
                                systemImage: isFavourite ? "star.fill" : "star"
                            )
                            .font(.muckHeadline)
                            .foregroundStyle(isFavourite ? Color.muckAmber : Color.muckNearBlack.opacity(0.5))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    // Hazard notice
                    if muck.isHazardous {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.muckRed)
                                .font(.system(size: 20))
                            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                Text("Managed by Authorities")
                                    .font(.muckHeadline)
                                    .foregroundStyle(Color.muckRed)
                                Text("Community events cannot be scheduled for hazardous mucks. Please contact your local council or EPA.")
                                    .font(.muckBody)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.7))
                            }
                        }
                        .padding(Spacing.md)
                        .background(Color.muckRed.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }

                    // Linked events
                    if muck.eventCount > 0 {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Scheduled Events")
                                .font(.muckTitle)
                                .foregroundStyle(Color.muckNearBlack)
                            Text("\(muck.eventCount) event\(muck.eventCount == 1 ? "" : "s") scheduled for this muck")
                                .font(.muckBody)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        }
                    }

                    Spacer(minLength: 120)
                }
                .padding(Spacing.md)
            }

            // Sticky bottom CTA
            if !muck.isHazardous {
                VStack(spacing: Spacing.xs) {
                    PrimaryButton(
                        title: "Add to a Community Event",
                        icon: "calendar.badge.plus"
                    ) {
                        showAddToEvent = true
                    }
                    Button {
                        // Close Muck flow
                    } label: {
                        Text("✕  Close this Muck")
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckRed.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .background(.regularMaterial)
            }
        }
        .navigationTitle(muck.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isFavourite = muckVM.isFavourite(muckId: muck.id)
        }
        .sheet(isPresented: $showAddToEvent) {
            AddToEventSheet(muck: muck)
        }
    }
}

#Preview {
    NavigationStack {
        ViewMuckView(muck: Muck.mockData[0])
    }
    .modelContainer(previewContainer)
    .environmentObject(MuckViewModel())
}
