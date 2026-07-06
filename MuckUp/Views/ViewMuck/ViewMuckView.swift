import SwiftUI
import SwiftData

struct ViewMuckView: View {
    @Bindable var muck: Muck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel

    @State private var showAddToEvent = false
    @State private var showCloseMuck = false
    @State private var isFavourite = false
    @State private var afterPhotoData: Data?
    @State private var showReportConfirm = false
    @State private var didReport = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Type header
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

                    // Mini map with nearby mucks
                    MuckMiniMapView(muck: muck)

                    // If both photos exist, the drag-to-reveal slider is the
                    // whole point of the app made visible — the transformation
                    // itself, not two static photos scrolled past separately.
                    if let beforeData = muck.photoData, let beforeUI = UIImage(data: beforeData),
                       let afterData = muck.afterPhotoData, let afterUI = UIImage(data: afterData) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Drag to compare")
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                            BeforeAfterSliderView(beforeImage: beforeUI, afterImage: afterUI)
                        }
                    } else {
                        // Before photo
                        if let data = muck.photoData, let ui = UIImage(data: data) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Before")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                        }

                        // After photo (only if closed, no before shown yet)
                        if muck.isClosed {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("After")
                                    .font(.muckCaption)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                                Text("No after photo recorded")
                                    .font(.muckBody)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.3))
                            }
                        }
                    }

                    Divider()

                    // Vote + Favourite
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

                        if muck.isClosed {
                            Label("Cleared", systemImage: "checkmark.seal.fill")
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckGreen)
                        }
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
                                Text("Community events cannot be scheduled for hazardous mucks. Contact your local council or EPA.")
                                    .font(.muckBody)
                                    .foregroundStyle(Color.muckNearBlack.opacity(0.7))
                            }
                        }
                        .padding(Spacing.md)
                        .background(Color.muckRed.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }

                    // Linked events count
                    if muck.eventCount > 0 {
                        Label(
                            "\(muck.eventCount) community event\(muck.eventCount == 1 ? "" : "s") scheduled",
                            systemImage: "calendar"
                        )
                        .font(.muckBody)
                        .foregroundStyle(Color.muckGreen)
                    }

                    Spacer(minLength: 120)
                }
                .padding(Spacing.md)
            }

            // Sticky bottom CTA
            if !muck.isHazardous && !muck.isClosed {
                VStack(spacing: Spacing.xs) {
                    PrimaryButton(
                        title: "Add to a Community Event",
                        icon: "calendar.badge.plus"
                    ) {
                        showAddToEvent = true
                    }
                    Button {
                        showCloseMuck = true
                    } label: {
                        Text("✓  Mark as Cleaned Up")
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckGreen.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.md)
                .background(.regularMaterial)
            }
        }
        .navigationTitle(muck.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showReportConfirm = true
                    } label: {
                        Label("Report this Muck", systemImage: "flag")
                    }
                    .disabled(!muckVM.canFlag(muck) || didReport)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                }
            }
        }
        .onAppear {
            isFavourite = muckVM.isFavourite(muckId: muck.id)
        }
        .sheet(isPresented: $showAddToEvent) {
            AddToEventSheet(muck: muck)
        }
        .sheet(isPresented: $showCloseMuck) {
            CloseMuckSheet(muck: muck)
        }
        .confirmationDialog(
            "Report this muck as spam, abuse, or a duplicate?",
            isPresented: $showReportConfirm,
            titleVisibility: .visible
        ) {
            Button("Report", role: .destructive) {
                muckVM.flag(muck)
                didReport = true
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
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
