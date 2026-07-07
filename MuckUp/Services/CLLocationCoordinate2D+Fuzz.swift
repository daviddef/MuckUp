import CoreLocation

extension CLLocationCoordinate2D {
    /// Offsets a coordinate by a random distance up to `radiusMetres` in a
    /// random direction — used for Junior Mode's map display so a child's
    /// exact position (often near home) isn't pinpointable, while still
    /// showing roughly the right neighbourhood. Display-only: never used
    /// for the actual "nearby" distance queries, which need real accuracy.
    func fuzzed(radiusMetres: Double = 300) -> CLLocationCoordinate2D {
        let distance = Double.random(in: 0...radiusMetres)
        let bearing = Double.random(in: 0..<(2 * .pi))

        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) + cos(lat1) * sin(distance / earthRadius) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(distance / earthRadius) * cos(lat1),
            cos(distance / earthRadius) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}
