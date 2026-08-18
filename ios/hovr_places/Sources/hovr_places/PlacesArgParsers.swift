enum PlacesArgParsers {
    struct AutocompleteArgs {
        let query: String
        let sessionToken: String
        let countries: [String]?
        let language: String?
    }

    struct PlaceDetailsArgs {
        let placeId: String
        let sessionToken: String
    }

    struct EndSessionArgs {
        let sessionToken: String
    }

    enum ParseResult<T> {
        case ok(T)
        case err(String)
    }

    static func parseAutocomplete(_ raw: Any?) -> ParseResult<AutocompleteArgs> {
        guard let map = stringKeyedMap(raw) else {
            return .err("Expected a map of arguments")
        }
        guard let query = requiredString(map, key: "query") else {
            return .err("query is required")
        }
        guard let sessionToken = requiredString(map, key: "sessionToken") else {
            return .err("sessionToken is required")
        }
        switch optionalStringList(map, key: "countries") {
        case .err(let message):
            return .err(message)
        case .ok(let countries):
            switch optionalString(map, key: "language") {
            case .err(let message):
                return .err(message)
            case .ok(let language):
                return .ok(
                    AutocompleteArgs(
                        query: query,
                        sessionToken: sessionToken,
                        countries: countries,
                        language: language
                    )
                )
            }
        }
    }

    static func parsePlaceDetails(_ raw: Any?) -> ParseResult<PlaceDetailsArgs> {
        guard let map = stringKeyedMap(raw) else {
            return .err("Expected a map of arguments")
        }
        guard let placeId = requiredString(map, key: "placeId") else {
            return .err("placeId is required")
        }
        guard let sessionToken = requiredString(map, key: "sessionToken") else {
            return .err("sessionToken is required")
        }
        return .ok(PlaceDetailsArgs(placeId: placeId, sessionToken: sessionToken))
    }

    static func parseEndSession(_ raw: Any?) -> ParseResult<EndSessionArgs> {
        guard let map = stringKeyedMap(raw) else {
            return .err("Expected a map of arguments")
        }
        guard let sessionToken = requiredString(map, key: "sessionToken") else {
            return .err("sessionToken is required")
        }
        return .ok(EndSessionArgs(sessionToken: sessionToken))
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
}
