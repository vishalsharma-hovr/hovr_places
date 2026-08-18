import GooglePlaces

/// Maps Dart-owned UUID strings to `GMSAutocompleteSessionToken` instances.
final class PlacesSessionStore {
    private var tokens: [String: GMSAutocompleteSessionToken] = [:]
    private let lock = NSLock()

    func token(for sessionToken: String) -> GMSAutocompleteSessionToken {
        lock.lock()
        defer { lock.unlock() }
        if let existing = tokens[sessionToken] {
            return existing
        }
        let created = GMSAutocompleteSessionToken()
        tokens[sessionToken] = created
        return created
    }

    func endSession(_ sessionToken: String) {
        lock.lock()
        tokens.removeValue(forKey: sessionToken)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        tokens.removeAll()
        lock.unlock()
    }
}
