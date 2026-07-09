import Foundation

extension URLSession {
    /// Shared session for the external open-data fetches (Brisbane City
    /// Council, waterway safety, etc.) — a 15s timeout so a slow/hanging
    /// endpoint doesn't leave a screen's loading spinner running far
    /// longer than the data is actually worth waiting for. `.shared`
    /// defaults to 60s, which is fine for a foreground request the user
    /// is actively waiting on, but too long for background "nearby data"
    /// fetches that should just degrade to empty and move on.
    static let grubData: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()
}
