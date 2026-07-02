import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct RaiseMuckPrefill {
    var description: String = ""
    var coordinate: CLLocationCoordinate2D?
    var address: String?
}

struct RaiseMuckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var muckVM: MuckViewModel
    @EnvironmentObject var locationService: LocationService

    var prefill: RaiseMuckPrefill = RaiseMuckPrefill()

    @State private var selectedType: MuckType = .cleanup
    @State private var description = ""
    @State private var isHazardous = false
    @State private var reportedDate = Date.now
    @State private var isSaved = false
    @State private var photoData: Data? = nil

    // Location picker state
    @State private var pickedCoordinate: CLLocationCoordinate2D? = nil
    @State private var pickedAddress: String = "Locating…"
    @State private var isDragging = false

    private var isValid: Bool {
        description.trimmingCharacters(in: .whitespaces).count >= 10 && photoData != nil
    }

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

                    // WHERE — location picker map
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Where is it?")
                            .font(.muckTitle)
                            .foregroundStyle(Color.muckNearBlack)

                        MuckLocationPicker(
                            userLocation: locationService.location,
                            initialCoordinate: prefill.coordinate,
                            isDragging: $isDragging,
                            onCoordinateChanged: { coord in
                                pickedCoordinate = coord
                                reverseGeocode(coord)
                            }
                        )
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .strokeBorder(Color.muckNearBlack.opacity(0.1))
                        )

                        // Address readout
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.muckGreen)
                                .font(.system(size: 14))
                            Text(isDragging ? "Drop to set location…" : pickedAddress)
                                .font(.muckBody)
                                .foregroundStyle(isDragging
                                    ? Color.muckNearBlack.opacity(0.4)
                                    : Color.muckNearBlack)
                                .animation(.easeInOut(duration: 0.15), value: isDragging)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.xs)
                    }

                    // Hazardous toggle
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

                    // Photo evidence — required
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xxs) {
                            Text("Add a photo")
                                .font(.muckTitle)
                                .foregroundStyle(Color.muckNearBlack)
                            Text("*")
                                .font(.muckTitle)
                                .foregroundStyle(Color.muckRed)
                        }
                        Text("A photo is what turns this into real evidence — for the community, and for councils.")
                            .font(.muckCaption)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        PhotoPickerButton(
                            label: "Take or choose a photo",
                            systemImage: "camera.fill",
                            imageData: $photoData
                        )
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
            .onAppear {
                if !prefill.description.isEmpty { description = prefill.description }
                if let coord = prefill.coordinate {
                    pickedCoordinate = coord
                    pickedAddress = prefill.address ?? pickedAddress
                }
            }
            .navigationDestination(isPresented: $isSaved) {
                MuckSavedView()
            }
            .onAppear {
                if let loc = locationService.location {
                    pickedCoordinate = loc.coordinate
                    reverseGeocode(loc.coordinate)
                } else {
                    pickedAddress = "Move the map to set location"
                }
            }
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            guard let place = placemarks?.first else { return }
            let parts = [place.name, place.locality, place.administrativeArea]
                .compactMap { $0 }
            pickedAddress = parts.prefix(2).joined(separator: ", ")
        }
    }

    private func submitMuck() {
        let coord = pickedCoordinate
            ?? locationService.location?.coordinate
            ?? CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)

        let newMuck = Muck(
            location: pickedAddress,
            description: description,
            type: selectedType,
            isHazardous: isHazardous,
            reportedDate: reportedDate,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
        newMuck.photoData = photoData
        modelContext.insert(newMuck)
        muckVM.award(.raiseMuck)
        muckVM.recordRaised(newMuck.id)
        isSaved = true
    }
}

// MARK: - Location Picker Map

struct MuckLocationPicker: UIViewRepresentable {
    let userLocation: CLLocation?
    var initialCoordinate: CLLocationCoordinate2D? = nil
    @Binding var isDragging: Bool
    let onCoordinateChanged: (CLLocationCoordinate2D) -> Void

    // Programmatic recenter (e.g. from an address search field). Bump
    // recenterToken whenever recenterCoordinate changes so the picker can
    // tell "same coordinate, re-rendered" apart from "new place to jump to".
    var recenterCoordinate: CLLocationCoordinate2D? = nil
    var recenterToken: Int = 0

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(isDragging: $isDragging, onCoordinateChanged: onCoordinateChanged)
        coordinator.hasDragged = initialCoordinate != nil
        return coordinator
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true          // blue glowing dot
        map.userTrackingMode = .none
        map.showsCompass = false
        map.pointOfInterestFilter = .excludingAll

        // Overlay crosshair — stays fixed at centre
        let crosshair = CrosshairView()
        crosshair.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(crosshair)
        NSLayoutConstraint.activate([
            crosshair.centerXAnchor.constraint(equalTo: map.centerXAnchor),
            crosshair.centerYAnchor.constraint(equalTo: map.centerYAnchor),
            crosshair.widthAnchor.constraint(equalToConstant: 44),
            crosshair.heightAnchor.constraint(equalToConstant: 44),
        ])
        context.coordinator.crosshair = crosshair

        // Default region — prefilled coordinate, user location, or Melbourne CBD
        let centre = initialCoordinate
            ?? userLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
        let region = MKCoordinateRegion(center: centre, latitudinalMeters: 500, longitudinalMeters: 500)
        map.setRegion(region, animated: false)

        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Address search jump — takes priority over the GPS auto-centre below.
        if let recenterCoordinate, recenterToken != context.coordinator.lastRecenterToken {
            context.coordinator.lastRecenterToken = recenterToken
            context.coordinator.hasDragged = true
            let region = MKCoordinateRegion(center: recenterCoordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
            return
        }

        // If we just got a user location and haven't been dragged yet, re-centre
        if !context.coordinator.hasDragged, let loc = userLocation {
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
            mapView.setRegion(region, animated: true)
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var isDragging: Bool
        let onCoordinateChanged: (CLLocationCoordinate2D) -> Void
        var hasDragged = false
        var lastRecenterToken = 0
        weak var crosshair: CrosshairView?

        init(isDragging: Binding<Bool>, onCoordinateChanged: @escaping (CLLocationCoordinate2D) -> Void) {
            self._isDragging = isDragging
            self.onCoordinateChanged = onCoordinateChanged
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Only treat gesture-driven changes as drags (not programmatic)
            if let gesture = mapView.subviews.first?.gestureRecognizers?.first(where: { $0.state == .began || $0.state == .changed }) {
                _ = gesture // gesture exists = user-driven
                hasDragged = true
                isDragging = true
                crosshair?.setLifted(true)
            } else if hasDragged {
                // Subsequent programmatic check
                isDragging = true
                crosshair?.setLifted(true)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            isDragging = false
            crosshair?.setLifted(false)
            onCoordinateChanged(mapView.centerCoordinate)
        }
    }
}

// MARK: - Crosshair View

final class CrosshairView: UIView {
    private let pinBody = UIView()
    private let pinShadow = UIView()
    private let pulseRing = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = .clear

        // Pulse ring — visible when dropped
        pulseRing.frame = CGRect(x: 10, y: 10, width: 24, height: 24)
        pulseRing.layer.cornerRadius = 12
        pulseRing.layer.borderWidth = 2
        pulseRing.layer.borderColor = UIColor(Color.muckGreen).withAlphaComponent(0.4).cgColor
        pulseRing.backgroundColor = UIColor(Color.muckGreen).withAlphaComponent(0.1)
        addSubview(pulseRing)

        // Pin shadow — small ellipse below pin tip
        pinShadow.frame = CGRect(x: 16, y: 36, width: 12, height: 4)
        pinShadow.layer.cornerRadius = 2
        pinShadow.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        addSubview(pinShadow)

        // Pin body — teardrop shape via CAShapeLayer
        let pinSize: CGFloat = 28
        let pinLayer = CAShapeLayer()
        pinLayer.path = teardropPath(size: pinSize).cgPath
        pinLayer.fillColor = UIColor(Color.muckGreen).cgColor
        pinLayer.shadowColor = UIColor.black.cgColor
        pinLayer.shadowOpacity = 0.25
        pinLayer.shadowOffset = CGSize(width: 0, height: 3)
        pinLayer.shadowRadius = 4

        pinBody.frame = CGRect(x: (44 - pinSize) / 2, y: 2, width: pinSize, height: pinSize + 6)
        pinBody.backgroundColor = .clear
        pinBody.layer.addSublayer(pinLayer)
        addSubview(pinBody)

        // White dot in centre of pin
        let dot = UIView(frame: CGRect(x: (pinSize - 8) / 2, y: (pinSize - 8) / 2 - 3, width: 8, height: 8))
        dot.layer.cornerRadius = 4
        dot.backgroundColor = .white
        pinBody.addSubview(dot)
    }

    private func teardropPath(size: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let r = size / 2
        let cx = r
        let cy = r - 2
        // Circle top
        path.addArc(withCenter: CGPoint(x: cx, y: cy), radius: r, startAngle: .pi, endAngle: 0, clockwise: true)
        // Taper to point at bottom
        path.addLine(to: CGPoint(x: cx + r, y: cy))
        path.addQuadCurve(to: CGPoint(x: cx, y: size + 4), controlPoint: CGPoint(x: cx + r, y: size))
        path.addQuadCurve(to: CGPoint(x: cx - r, y: cy), controlPoint: CGPoint(x: cx - r, y: size))
        path.close()
        return path
    }

    func setLifted(_ lifted: Bool) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            // Lift pin up, shrink shadow
            self.pinBody.transform = lifted
                ? CGAffineTransform(translationX: 0, y: -10)
                : .identity
            self.pinShadow.transform = lifted
                ? CGAffineTransform(scaleX: 0.5, y: 0.5)
                : .identity
            self.pinShadow.alpha = lifted ? 0.15 : 0.7
            // Hide pulse ring while dragging
            self.pulseRing.alpha = lifted ? 0 : 1
        }
        // Pulse animation when dropped
        if !lifted {
            pulseRing.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.5, initialSpringVelocity: 1) {
                self.pulseRing.transform = .identity
            }
        }
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
                    .foregroundStyle(isSelected ? .white : Color.muckNearBlack)
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
    @State private var celebrate = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.muckGreen)
                .confettiBurst(trigger: $celebrate)
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
        .onAppear { celebrate = true }
    }
}

#Preview {
    RaiseMuckView()
        .modelContainer(previewContainer)
        .environmentObject(MuckViewModel())
        .environmentObject(LocationService())
}
