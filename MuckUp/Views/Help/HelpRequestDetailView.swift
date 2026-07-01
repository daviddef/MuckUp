import SwiftUI
import SwiftData
import MapKit

struct HelpRequestDetailView: View {
    @Bindable var request: HelpRequest
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var helpVM: HelpViewModel
    @EnvironmentObject var locationService: LocationService

    @State private var justOffered = false

    private var isMine: Bool { helpVM.isMine(request) }
    private var hasOffered: Bool { helpVM.hasOffered(request) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                HStack {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: request.category.icon)
                        Text(request.category.displayName)
                    }
                    .font(.muckCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(Color.helpCategoryColor(request.category))
                    .clipShape(Capsule())

                    Spacer()

                    statusBadge
                }

                Text(request.title)
                    .font(.muckDisplay)
                    .foregroundStyle(Color.muckNearBlack)

                if let data = request.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }

                Text(request.requestDescription)
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.8))

                Divider()

                Label(request.preferredDate.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                    .font(.muckHeadline)
                    .foregroundStyle(Color.muckAmber)

                // Blurred area map
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Approximate area")
                        .font(.muckCaption)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                    BlurredAreaMapView(request: request)
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 11))
                        Text("Exact address is private and only shared once help is confirmed.")
                            .font(.muckMicro)
                    }
                    .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                }

                // Helpers
                if !request.helperIds.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Label("\(request.helperIds.count) neighbour\(request.helperIds.count == 1 ? "" : "s") offered to help", systemImage: "hands.sparkles.fill")
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckGreen)
                    }
                }

                // Actions
                if isMine {
                    if request.status != .completed {
                        PrimaryButton(title: "Mark as Resolved", icon: "checkmark.seal.fill") {
                            markResolved()
                        }
                    } else {
                        Label("Resolved — thank your helpers!", systemImage: "checkmark.seal.fill")
                            .font(.muckHeadline)
                            .foregroundStyle(Color.muckGreen)
                    }
                } else if request.status == .completed {
                    Label("This request has been resolved", systemImage: "checkmark.seal.fill")
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                } else if hasOffered || justOffered {
                    Label("You offered to help — the requester can see your interest", systemImage: "checkmark.circle.fill")
                        .font(.muckHeadline)
                        .foregroundStyle(Color.muckGreen)
                } else {
                    PrimaryButton(title: "I Can Help", icon: "hand.raised.fill") {
                        offerHelp()
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.muckBg)
        .navigationTitle("Help Request")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusBadge: some View {
        Group {
            switch request.status {
            case .open:      Text("Open").foregroundStyle(Color.muckGreen)
            case .matched:   Text("Helper Found").foregroundStyle(Color.muckAmber)
            case .completed: Text("Resolved").foregroundStyle(Color.muckNearBlack.opacity(0.4))
            }
        }
        .font(.muckCaption)
    }

    private func offerHelp() {
        guard helpVM.offerHelp(request) else { return }
        muckVM.recordHelpOffered(request.id)
        muckVM.award(.offerHelp)
        justOffered = true
    }

    private func markResolved() {
        helpVM.markCompleted(request)
        muckVM.award(.requestResolved)
        // Per-helper crediting would need a real backend to reach every
        // offerer's device — this local demo only credits the current one.
        if helpVM.hasOffered(request) {
            muckVM.recordHelpCompleted(request.id)
            muckVM.award(.helpCompleted)
        }
    }
}

// MARK: - Blurred area map

private struct BlurredAreaMapView: View {
    let request: HelpRequest
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition) {
            MapCircle(center: request.blurredCoordinate, radius: request.blurRadiusMetres)
                .foregroundStyle(Color.helpCategoryColor(request.category).opacity(0.18))
                .stroke(Color.helpCategoryColor(request.category), lineWidth: 1.5)
        }
        .mapStyle(.standard(elevation: .flat))
        .disabled(true)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.muckNearBlack.opacity(0.08))
        )
        .onAppear {
            cameraPosition = .camera(MapCamera(centerCoordinate: request.blurredCoordinate, distance: 2400))
        }
    }
}
