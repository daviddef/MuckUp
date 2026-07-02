import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct AskForHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService

    @State private var title = ""
    @State private var description = ""
    @State private var category: HelpCategory = .yardWork
    @State private var preferredDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    @State private var photoData: Data?
    @State private var isSaved = false

    @State private var pickedCoordinate: CLLocationCoordinate2D?
    @State private var pickedAddress: String = "Locating…"
    @State private var isDragging = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        description.trimmingCharacters(in: .whitespaces).count >= 10
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Category
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("What kind of help do you need?")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.xs)], spacing: Spacing.xs) {
                            ForEach(HelpCategory.allCases, id: \.self) { cat in
                                Button {
                                    category = cat
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    VStack(spacing: Spacing.xxs) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 18))
                                        Text(cat.displayName)
                                            .font(.muckCaption)
                                    }
                                    .foregroundStyle(category == cat ? .white : Color.muckNearBlack.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.sm)
                                    .background(category == cat ? Color.helpCategoryColor(cat) : Color.muckSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Title
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Title")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        TextField("e.g. Overgrown yard needs a working bee", text: $title)
                            .font(.muckBody)
                            .padding(Spacing.sm)
                            .background(Color.muckSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }

                    // Description
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("What do you need help with?")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        TextEditor(text: $description)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack)
                            .frame(minHeight: 90)
                            .padding(Spacing.sm)
                            .background(Color.muckSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        if description.count < 10 && !description.isEmpty {
                            Text("A little more detail helps neighbours know if they can help (10+ characters).")
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckRed)
                        }
                    }

                    // WHERE — location picker, exact for you, blurred for others
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Where")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)

                        MuckLocationPicker(
                            userLocation: locationService.location,
                            isDragging: $isDragging,
                            onCoordinateChanged: { coord in
                                pickedCoordinate = coord
                                reverseGeocode(coord)
                            }
                        )
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .strokeBorder(Color.muckNearBlack.opacity(0.1))
                        )

                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.muckGreen)
                                .font(.system(size: 14))
                            Text(isDragging ? "Drop to set location…" : pickedAddress)
                                .font(.muckBody)
                                .foregroundStyle(isDragging
                                    ? Color.muckNearBlack.opacity(0.4)
                                    : Color.muckNearBlack)
                            Spacer()
                        }

                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                            Text("Your exact address stays private. Neighbours will only see an approximate area (~400m) until you accept their help.")
                                .font(.muckMicro)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.4))
                        }
                    }

                    // When
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("When would help be useful?")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        DatePicker("", selection: $preferredDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(Color.muckGreen)
                    }

                    // Photo — optional here, this is personal not evidentiary
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Add a photo (optional)")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)
                        PhotoPickerButton(
                            label: "Show what needs doing",
                            systemImage: "camera.fill",
                            imageData: $photoData
                        )
                    }

                    PrimaryButton(
                        title: "Post Request",
                        icon: "hand.raised.fill",
                        isDisabled: !isValid
                    ) {
                        submit()
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(Spacing.md)
            }
            .background(Color.muckBg)
            .navigationTitle("Ask for Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.muckNearBlack)
                }
            }
            .navigationDestination(isPresented: $isSaved) {
                HelpRequestSavedView(onDone: { dismiss() })
            }
            .onAppear {
                if let loc = locationService.location {
                    pickedCoordinate = loc.coordinate
                    reverseGeocode(loc.coordinate)
                } else {
                    pickedAddress = "Move the map to set your area"
                }
            }
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            guard let place = placemarks?.first else { return }
            let parts = [place.locality, place.administrativeArea].compactMap { $0 }
            pickedAddress = parts.isEmpty ? "Pinned location" : parts.joined(separator: ", ")
        }
    }

    private func submit() {
        let coord = pickedCoordinate
            ?? locationService.location?.coordinate
            ?? CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)

        let request = HelpRequest(
            title: title,
            description: description,
            category: category,
            preferredDate: preferredDate,
            exactLatitude: coord.latitude,
            exactLongitude: coord.longitude,
            requesterId: muckVM.userId
        )
        request.photoData = photoData
        modelContext.insert(request)
        muckVM.recordHelpPosted(request.id)
        muckVM.award(.askForHelp)
        isSaved = true
    }
}

struct HelpRequestSavedView: View {
    let onDone: () -> Void
    @State private var celebrate = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.muckGreen)
                .confettiBurst(trigger: $celebrate)
            Text("Request Posted!")
                .font(.muckDisplay)
                .foregroundStyle(Color.muckNearBlack)
            Text("Neighbours nearby will be able to see your request and offer to help.")
                .font(.muckBody)
                .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            PrimaryButton(title: "Done") {
                onDone()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.muckBg.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .onAppear { celebrate = true }
    }
}
