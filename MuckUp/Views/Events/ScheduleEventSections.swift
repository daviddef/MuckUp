import SwiftUI
import CoreLocation

// Two of ScheduleEventView's List sections, pulled out as their own views —
// each is a self-contained chunk of row content (the Section/header/footer
// wrapper stays in ScheduleEventView since that's where the List lives).

/// "Where — Meeting Point": address search + draggable map pin + resolved
/// address line.
struct MeetupLocationRow: View {
    @Binding var addressSearchText: String
    let isSearchingAddress: Bool
    let addressSearchError: String?
    let userLocation: CLLocation?
    let initialCoordinate: CLLocationCoordinate2D?
    @Binding var isDraggingMeetup: Bool
    let pickedMeetupAddress: String
    let recenterCoordinate: CLLocationCoordinate2D?
    let recenterToken: Int
    let onSearch: () -> Void
    let onCoordinateChanged: (CLLocationCoordinate2D) -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Color.muckNearBlack.opacity(0.35))
            TextField("Search an address…", text: $addressSearchText)
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack)
                .submitLabel(.search)
                .onSubmit(onSearch)
            if isSearchingAddress {
                ProgressView().tint(Color.muckGreen)
            } else if !addressSearchText.isEmpty {
                Button(action: onSearch) {
                    Text("Go")
                        .font(.muckCaption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Color.muckGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xxxs)

        if let addressSearchError {
            Text(addressSearchError)
                .font(.muckCaption)
                .foregroundStyle(Color.muckRed)
        }

        MuckLocationPicker(
            userLocation: userLocation,
            initialCoordinate: initialCoordinate,
            isDragging: $isDraggingMeetup,
            onCoordinateChanged: onCoordinateChanged,
            recenterCoordinate: recenterCoordinate,
            recenterToken: recenterToken
        )
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .strokeBorder(Color.muckNearBlack.opacity(0.1))
        )
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))

        HStack(spacing: Spacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(Color.muckGreen)
                .font(.system(size: 14))
            Text(isDraggingMeetup ? "Drop to set the meeting point…" : pickedMeetupAddress)
                .font(.muckBody)
                .foregroundStyle(isDraggingMeetup
                    ? Color.muckNearBlack.opacity(0.4)
                    : Color.muckNearBlack)
                .animation(.easeInOut(duration: 0.15), value: isDraggingMeetup)
            Spacer()
        }
    }
}

/// "Things to be aware of in this area" — loading state or a list of
/// nearby waterway/animal-complaint items from AwarenessViewModel.
struct AwarenessSectionRows: View {
    let isLoadingAwareness: Bool
    let nearbyAwarenessItems: [AwarenessItem]
    let onSelect: (AwarenessItem) -> Void

    var body: some View {
        if isLoadingAwareness {
            HStack(spacing: Spacing.xs) {
                ProgressView().tint(Color.muckGreen)
                Text("Checking the area…")
                    .font(.muckBody)
                    .foregroundStyle(Color.muckNearBlack.opacity(0.5))
            }
            .padding(.vertical, Spacing.xxs)
        } else {
            ForEach(nearbyAwarenessItems) { item in
                Button {
                    onSelect(item)
                } label: {
                    AwarenessRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
