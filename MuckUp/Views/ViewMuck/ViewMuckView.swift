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

                    // After photo (only if closed or has one)
                    if muck.isClosed || muck.afterPhotoData != nil {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("After")
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                            if let data = muck.afterPhotoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            } else {
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
        .onAppear {
            isFavourite = muckVM.isFavourite(muckId: muck.id)
        }
        .sheet(isPresented: $showAddToEvent) {
            AddToEventSheet(muck: muck)
        }
        .sheet(isPresented: $showCloseMuck) {
            CloseMuckSheet(muck: muck)
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
