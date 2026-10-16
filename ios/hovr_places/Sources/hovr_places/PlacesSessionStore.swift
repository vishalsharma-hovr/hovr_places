import GooglePlaces

/// Maps Dart-owned UUID strings to `GMSAutocompleteSessionToken` instances.
/// Holds at most `maxSessions` so sessions Dart never closes cannot pile up;
/// the oldest goes first.
final class PlacesSessionStore {
    static let defaultMaxSessions = 32

    private var tokens: [String: GMSAutocompleteSessionToken] = [:]
    private var order: [String] = []
    private let maxSessions: Int
    private let lock = NSLock()

    init(maxSessions: Int = PlacesSessionStore.defaultMaxSessions) {
        self.maxSessions = maxSessions
    }

    func token(for sessionToken: String) -> GMSAutocompleteSessionToken {
        lock.lock()
        defer { lock.unlock() }
        if let existing = tokens[sessionToken] {
            return existing
        }
        let created = GMSAutocompleteSessionToken()
        tokens[sessionToken] = created
        order.append(sessionToken)
        if order.count > maxSessions {
            tokens.removeValue(forKey: order.removeFirst())
        }
        return created
    }

    func endSession(_ sessionToken: String) {
        lock.lock()
        tokens.removeValue(forKey: sessionToken)
        order.removeAll { $0 == sessionToken }
        lock.unlock()
    }

    func clear() {
        lock.lock()
        tokens.removeAll()
        order.removeAll()
        lock.unlock()
    }
}
