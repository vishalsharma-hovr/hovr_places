import Foundation

enum PlacesArgParsers {
    struct AutocompleteArgs {
        let query: String
        let sessionToken: String
        let countries: [String]?
        let language: String?
        var origin: LatLngArg?
        var locationBias: AreaArg?
        var locationRestriction: AreaArg?
        var types: [String]?
        var regionCode: String?
        /// Validated for parity with Android; iOS cannot cancel requests.
        var cancelPrevious = false
    }

    struct LatLngArg: Equatable {
        let lat: Double
        let lng: Double
    }

    enum AreaArg: Equatable {
        case circle(center: LatLngArg, radiusMeters: Double)
        case rectangle(southwest: LatLngArg, northeast: LatLngArg)
    }

    struct PlaceDetailsArgs {
        let placeId: String
        let sessionToken: String
        var fields: [String] = []
        var regionCode: String?
    }

    struct SearchNearbyArgs {
        let center: LatLngArg
        let radiusMeters: Double
        let types: [String]?
        let maxResults: Int?
        let rankByDistance: Bool
        let fields: [String]
        let regionCode: String?
    }

    struct EndSessionArgs {
        let sessionToken: String
    }

    enum ParseResult<T> {
        case ok(T)
        case err(String)
    }

    /// Optional place-details fields Dart may request, by channel name.
    static let detailFields: Set<String> = ["name", "addressComponents", "viewport", "plusCode"]
    static let maxRadiusMeters = 50_000.0
    static let maxAutocompleteTypes = 5
    static let maxCountries = 15
    static let maxNearbyTypes = 50
    static let maxNearbyResults = 20

    static func parseAutocomplete(_ raw: Any?) -> ParseResult<AutocompleteArgs> {
        parsing {
            let map = try argsMap(raw)
            let bias = try map["locationBias"].map { try area($0, key: "locationBias") }
            let restriction = try map["locationRestriction"].map {
                try area($0, key: "locationRestriction")
            }
            if bias != nil && restriction != nil {
                throw Invalid("Pass locationBias or locationRestriction, not both")
            }
            return AutocompleteArgs(
                query: try required(map, "query"),
                sessionToken: try required(map, "sessionToken"),
                countries: try countries(map),
                language: try optionalString(map, key: "language").get(),
                origin: try map["origin"].map { try latLng($0, key: "origin") },
                locationBias: bias,
                locationRestriction: restriction,
                types: try types(map, max: maxAutocompleteTypes),
                regionCode: try regionCode(map),
                cancelPrevious: try cancelPrevious(map)
            )
        }
    }

    static func parsePlaceDetails(_ raw: Any?) -> ParseResult<PlaceDetailsArgs> {
        parsing {
            let map = try argsMap(raw)
            return PlaceDetailsArgs(
                placeId: try required(map, "placeId"),
                sessionToken: try required(map, "sessionToken"),
                fields: try fields(map),
                regionCode: try regionCode(map)
            )
        }
    }

    static func parseSearchNearby(_ raw: Any?) -> ParseResult<SearchNearbyArgs> {
        parsing {
            let map = try argsMap(raw)
            let circle = try area(
                ["type": "circle", "center": map["center"] as Any, "radiusMeters": map["radiusMeters"] as Any],
                key: "area"
            )
            guard case .circle(let center, let radius) = circle else { throw Invalid("area must be a circle") }
            var maxResults: Int?
            if let raw = map["maxResults"] {
                guard let count = (raw as? NSNumber)?.intValue, (1...maxNearbyResults).contains(count) else {
                    throw Invalid("maxResults must be 1–\(maxNearbyResults)")
                }
                maxResults = count
            }
            let rankBy = map["rankBy"] as? String ?? "popularity"
            guard rankBy == "distance" || rankBy == "popularity" else {
                throw Invalid("rankBy must be \"distance\" or \"popularity\"")
            }
            return SearchNearbyArgs(
                center: center,
                radiusMeters: radius,
                types: try types(map, max: maxNearbyTypes),
                maxResults: maxResults,
                rankByDistance: rankBy == "distance",
                fields: try fields(map),
                regionCode: try regionCode(map)
            )
        }
    }

    static func parseEndSession(_ raw: Any?) -> ParseResult<EndSessionArgs> {
        parsing { EndSessionArgs(sessionToken: try required(try argsMap(raw), "sessionToken")) }
    }

    static func parseLatLng(_ raw: Any?, key: String) -> ParseResult<LatLngArg> {
        parsing { try latLng(raw, key: key) }
    }

    static func parseArea(_ raw: Any?, key: String) -> ParseResult<AreaArg> {
        parsing { try area(raw, key: key) }
    }

    static func stringKeyedMap(_ raw: Any?) -> [String: Any]? {
        guard let map = raw as? [String: Any] else { return nil }
        return map
    }

    static func requiredString(_ map: [String: Any], key: String) -> String? {
        guard let value = map[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func optionalString(_ map: [String: Any], key: String) -> ParseResult<String?> {
        guard let value = map[key] else { return .ok(nil) }
        guard let string = value as? String else { return .err("\(key) must be a String") }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return .ok(trimmed.isEmpty ? nil : trimmed)
    }

    static func optionalStringList(_ map: [String: Any], key: String) -> ParseResult<[String]?> {
        guard let value = map[key] else { return .ok(nil) }
        guard let list = value as? [Any] else { return .err("\(key) must be a List") }
        var out: [String] = []
        for item in list {
            guard let string = item as? String else {
                return .err("\(key) must contain only Strings")
            }
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { out.append(trimmed) }
        }
        return .ok(out)
    }

    // MARK: - Throwing helpers: each parser reads top to bottom, first error wins.

    fileprivate struct Invalid: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }

    private static func parsing<T>(_ body: () throws -> T) -> ParseResult<T> {
        do {
            return .ok(try body())
        } catch let error as Invalid {
            return .err(error.message)
        } catch {
            return .err("Invalid arguments")
        }
    }

    private static func argsMap(_ raw: Any?) throws -> [String: Any] {
        guard let map = stringKeyedMap(raw) else { throw Invalid("Expected a map of arguments") }
        return map
    }

    private static func required(_ map: [String: Any], _ key: String) throws -> String {
        guard let value = requiredString(map, key: key) else { throw Invalid("\(key) is required") }
        return value
    }

    private static func latLng(_ raw: Any?, key: String) throws -> LatLngArg {
        guard let map = stringKeyedMap(raw),
              let lat = (map["lat"] as? NSNumber)?.doubleValue,
              let lng = (map["lng"] as? NSNumber)?.doubleValue,
              // abs(NaN) <= 90 is false, so NaN is rejected too.
              abs(lat) <= 90, abs(lng) <= 180
        else {
            throw Invalid("\(key) needs lat in [-90, 90] and lng in [-180, 180]")
        }
        return LatLngArg(lat: lat, lng: lng)
    }

    private static func area(_ raw: Any?, key: String) throws -> AreaArg {
        guard let map = stringKeyedMap(raw) else { throw Invalid("\(key) must be a map") }
        switch map["type"] as? String {
        case "circle":
            let center = try latLng(map["center"], key: "\(key).center")
            guard let radius = (map["radiusMeters"] as? NSNumber)?.doubleValue,
                  radius > 0, radius <= maxRadiusMeters
            else {
                throw Invalid("\(key).radiusMeters must be in (0, 50000]")
            }
            return .circle(center: center, radiusMeters: radius)
        case "rectangle":
            let sw = try latLng(map["southwest"], key: "\(key).southwest")
            let ne = try latLng(map["northeast"], key: "\(key).northeast")
            guard sw.lat <= ne.lat else {
                throw Invalid("\(key).southwest must be south of \(key).northeast")
            }
            return .rectangle(southwest: sw, northeast: ne)
        default:
            throw Invalid("\(key).type must be \"circle\" or \"rectangle\"")
        }
    }

    private static func types(_ map: [String: Any], max: Int) throws -> [String]? {
        guard let types = try optionalStringList(map, key: "types").get() else { return nil }
        guard !types.isEmpty, types.count <= max else { throw Invalid("types must have 1–\(max) entries") }
        return types
    }

    private static func countries(_ map: [String: Any]) throws -> [String]? {
        guard let countries = try optionalStringList(map, key: "countries").get() else { return nil }
        let twoLetters = countries.allSatisfy { $0.count == 2 && $0.allSatisfy { $0.isASCII && $0.isLetter } }
        guard countries.count <= maxCountries, twoLetters else {
            throw Invalid("countries must be up to \(maxCountries) 2-letter codes")
        }
        return countries
    }

    private static func regionCode(_ map: [String: Any]) throws -> String? {
        guard let code = try optionalString(map, key: "regionCode").get() else { return nil }
        guard code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }) else {
            throw Invalid("regionCode must be 2 letters")
        }
        return code
    }

    private static func cancelPrevious(_ map: [String: Any]) throws -> Bool {
        guard let value = map["cancelPrevious"] else { return false }
        // NSNumber(1) also casts to Bool, so require an actual boolean.
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
            throw Invalid("cancelPrevious must be a bool")
        }
        return number.boolValue
    }

    private static func fields(_ map: [String: Any]) throws -> [String] {
        guard let fields = try optionalStringList(map, key: "fields").get() else { return [] }
        let unknown = fields.filter { !detailFields.contains($0) }
        guard unknown.isEmpty else { throw Invalid("Unknown fields: \(unknown)") }
        return fields
    }
}

private extension PlacesArgParsers.ParseResult {
    func get() throws -> T {
        switch self {
        case .ok(let value): return value
        case .err(let message): throw PlacesArgParsers.Invalid(message)
        }
    }
}
