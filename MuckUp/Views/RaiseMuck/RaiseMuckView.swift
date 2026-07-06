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
    @State private var showDetails = false

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

                    // Photo comes first — snap it, then everything else
                    // follows. This is the evidence the whole report is
                    // built around, so it shouldn't be buried mid-form.
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("What did you find?")
                            .font(.muckDisplay)
                            .foregroundStyle(Color.muckNearBlack)
                        Text("Take a photo to get started — the details below fill in around it.")
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.5))
                        PhotoPickerButton(
                            label: "Take or choose a photo",
                            systemImage: "camera.fill",
                            imageData: $photoData
                        )
                    }

                    if photoData != nil {
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

                        // More details — collapsed by default, most
                        // reports don't need to touch these
                        DisclosureGroup(isExpanded: $showDetails) {
                            VStack(alignment: .leading, spacing: Spacing.md) {
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

                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text("When did you notice this?")
                                        .font(.muckHeadline)
                                        .foregroundStyle(Color.muckNearBlack)
                                    DatePicker("", selection: $reportedDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                                        .labelsHidden()
                                        .tint(Color.muckGreen)
                                }
                            }
                            .padding(.top, Spacing.sm)
                        } label: {
                            Label(isHazardous ? "Hazardous · custom date" : "Hazard flag, date & more", systemImage: "slider.horizontal.3")
                                .font(.muckCaption)
                                .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                        }
                        .padding(Spacing.sm)
                        .background(Color.muckSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                        PrimaryButton(
                            title: "Submit Muck",
                            icon: "checkmark",
                            isDisabled: !isValid
                        ) {
                            submitMuck()
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
                .padding(Spacing.md)
                .animation(.easeInOut(duration: 0.25), value: photoData == nil)
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
    // tell "same coordinate re-rendered" apart from "new place to jump to".
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
    private let shadowLayer = CAShapeLayer()
    private let pinLayer = CAShapeLayer()
    private let dotLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        shadowLayer.fillColor = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.addSublayer(shadowLayer)

        pinLayer.fillColor = UIColor.white.cgColor
        pinLayer.shadowColor = UIColor.black.cgColor
        pinLayer.shadowOpacity = 0.25
        pinLayer.shadowOffset = CGSize(width: 0, height: 2)
        pinLayer.shadowRadius = 3
        layer.addSublayer(pinLayer)

        dotLayer.fillColor = UIColor(Color.muckGreen).cgColor
        layer.addSublayer(dotLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawPin(lifted: false)
    }

    func setLifted(_ lifted: Bool) {
        UIView.animate(withDuration: 0.15) {
            self.drawPin(lifted: lifted)
        }
    }

    private func drawPin(lifted: Bool) {
        let w = bounds.width
        let h = bounds.height
        let liftOffset: CGFloat = lifted ? -8 : 0

        // Teardrop pin shape
        let pinWidth: CGFloat = w * 0.55
        let pinHeight: CGFloat = h * 0.8
        let cx = w / 2
        let topY = (h - pinHeight) / 2 + liftOffset

        let path = UIBezierPath()
        let radius = pinWidth / 2
        path.addArc(withCenter: CGPoint(x: cx, y: topY + radius), radius: radius, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addQuadCurve(
            to: CGPoint(x: cx, y: topY + pinHeight),
            controlPoint: CGPoint(x: cx + radius, y: topY + pinHeight * 0.7)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx - radius, y: topY + radius),
            controlPoint: CGPoint(x: cx - radius, y: topY + pinHeight * 0.7)
        )
        path.close()
        pinLayer.path = path.cgPath

        // Inner dot
        let dotRadius = radius * 0.4
        let dotPath = UIBezierPath(
            arcCenter: CGPoint(x: cx, y: topY + radius),
            radius: dotRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        dotLayer.path = dotPath.cgPath

        // Shadow ellipse at ground level — shrinks when lifted
        let shadowScale: CGFloat = lifted ? 0.7 : 1.0
        let shadowWidth = pinWidth * 0.6 * shadowScale
        let shadowRect = CGRect(
            x: cx - shadowWidth / 2,
            y: h - 6,
            width: shadowWidth,
            height: 5
        )
        shadowLayer.path = UIBezierPath(ovalIn: shadowRect).cgPath
    }
}

// MARK: - Type Selector Card

private struct TypeSelectorCard: View {
    let type: MuckType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                Text(type.displayName)
                    .font(.muckCaption)
            }
            .foregroundStyle(isSelected ? .white : Color.muckNearBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
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
