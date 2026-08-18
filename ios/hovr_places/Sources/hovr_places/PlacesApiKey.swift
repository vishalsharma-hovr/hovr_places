import Foundation

/// Reads the Google API key from the host app Info.plist.
/// The key is never returned to Dart and must never be logged.
enum PlacesApiKey {
    static var googleMapsApiKey: String {
        let info = Bundle.main.infoDictionary
        let raw = (info?["GOOGLE_MAPS_API_KEY"] as? String)
            ?? (info?["GMSApiKey"] as? String)
            ?? ""
        return normalized(raw)
    }

    static var isConfigured: Bool {
        !googleMapsApiKey.isEmpty
    }

    static func normalized(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("$(") && trimmed.hasSuffix(")") { return "" }
        if trimmed.uppercased().contains("YOUR_API_KEY") { return "" }
        return trimmed
    }
}
