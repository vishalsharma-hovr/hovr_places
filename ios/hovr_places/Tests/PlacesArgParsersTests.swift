import XCTest
@testable import hovr_places

final class PlacesArgParsersTests: XCTestCase {
    func testParseAutocompleteReadsFields() {
        let result = PlacesArgParsers.parseAutocomplete([
            "query": " union station ",
            "sessionToken": "abc-123",
            "countries": ["CA", "IN"],
            "language": "en",
        ])
        guard case .ok(let args) = result else {
            XCTFail("Expected ok")
            return
        }
        XCTAssertEqual(args.query, "union station")
        XCTAssertEqual(args.sessionToken, "abc-123")
        XCTAssertEqual(args.countries, ["CA", "IN"])
        XCTAssertEqual(args.language, "en")
    }

    func testParseAutocompleteRejectsMissingQuery() {
        let result = PlacesArgParsers.parseAutocomplete(["sessionToken": "abc-123"])
        guard case .err = result else {
            XCTFail("Expected err")
            return
        }
    }

    func testParseAutocompleteRejectsNonMap() {
        let result = PlacesArgParsers.parseAutocomplete("union station")
        guard case .err = result else {
            XCTFail("Expected err")
            return
        }
    }

    func testParsePlaceDetailsReadsIds() {
        let result = PlacesArgParsers.parsePlaceDetails([
            "placeId": "ChIJd",
            "sessionToken": "tok",
        ])
        guard case .ok(let args) = result else {
            XCTFail("Expected ok")
            return
        }
        XCTAssertEqual(args.placeId, "ChIJd")
        XCTAssertEqual(args.sessionToken, "tok")
    }

    func testParseEndSessionReadsToken() {
        let result = PlacesArgParsers.parseEndSession(["sessionToken": "tok"])
        guard case .ok(let args) = result else {
            XCTFail("Expected ok")
            return
        }
        XCTAssertEqual(args.sessionToken, "tok")
    }

    func testApiKeyNormalizerRejectsPlaceholders() {
        XCTAssertEqual(PlacesApiKey.normalized(""), "")
        XCTAssertEqual(PlacesApiKey.normalized("YOUR_API_KEY"), "")
        XCTAssertEqual(PlacesApiKey.normalized("$(GOOGLE_MAPS_API_KEY)"), "")
        XCTAssertEqual(PlacesApiKey.normalized("  AIzaSyValidLookingKey  "), "AIzaSyValidLookingKey")
    }

    private func autocomplete(_ extra: [String: Any]) -> PlacesArgParsers.ParseResult<PlacesArgParsers.AutocompleteArgs> {
        PlacesArgParsers.parseAutocomplete(
            ["query": "union", "sessionToken": "tok"].merging(extra) { _, new in new }
        )
    }

    private let circle: [String: Any] = [
        "type": "circle",
        "center": ["lat": 43.65, "lng": -79.38],
        "radiusMeters": 5000.0,
    ]

    func testParseAutocompleteReadsOriginAndCircleBias() {
        let result = autocomplete([
            "origin": ["lat": 43.65, "lng": -79.38],
            "locationBias": circle,
        ])
        guard case .ok(let args) = result else {
            XCTFail("Expected ok for a valid origin and circle bias")
            return
        }
        let center = PlacesArgParsers.LatLngArg(lat: 43.65, lng: -79.38)
        XCTAssertEqual(args.origin, center, "origin")
        XCTAssertEqual(args.locationBias, .circle(center: center, radiusMeters: 5000), "circle bias")
    }

    func testParseAutocompleteReadsRectangleRestrictionWithIntCoords() {
        let result = autocomplete([
            "locationRestriction": [
                "type": "rectangle",
                "southwest": ["lat": 43, "lng": -80],
                "northeast": ["lat": 44, "lng": -79],
            ],
        ])
        guard case .ok(let args) = result, case .rectangle = args.locationRestriction else {
            XCTFail("Dart may send whole numbers as Int; they must still parse")
            return
        }
    }

    func testParseAutocompleteRejectsBadLocations() {
        var bigCircle = circle
        bigCircle["radiusMeters"] = 60000.0
        let bad: [String: [String: Any]] = [
            "origin out of range": ["origin": ["lat": 95.0, "lng": 0.0]],
            "origin NaN": ["origin": ["lat": Double.nan, "lng": 0.0]],
            "radius over 50 km": ["locationBias": bigCircle],
            "unknown area type": ["locationBias": ["type": "polygon"]],
            "bias and restriction together": ["locationBias": circle, "locationRestriction": circle],
            "swapped rectangle corners": ["locationRestriction": [
                "type": "rectangle",
                "southwest": ["lat": 44.0, "lng": -80.0],
                "northeast": ["lat": 43.0, "lng": -79.0],
            ]],
        ]
        for (why, extra) in bad {
            guard case .err = autocomplete(extra) else {
                XCTFail("expected INVALID_ARGUMENT for: \(why)")
                continue
            }
        }
    }

    func testParseAutocompleteReadsTypesAndRegionCode() {
        guard case .ok(let args) = autocomplete(["types": ["airport"], "regionCode": "IN"]) else {
            XCTFail("Expected ok for valid types and regionCode")
            return
        }
        XCTAssertEqual(args.types, ["airport"], "types")
        XCTAssertEqual(args.regionCode, "IN", "regionCode")
    }

    func testParseAutocompleteRejectsBadTypesAndRegion() {
        let bad: [String: [String: Any]] = [
            "6 types": ["types": Array(repeating: "airport", count: 6)],
            "empty types": ["types": [String]()],
            "3-letter region": ["regionCode": "IND"],
        ]
        for (why, extra) in bad {
            guard case .err = autocomplete(extra) else {
                XCTFail("expected INVALID_ARGUMENT for: \(why)")
                continue
            }
        }
    }

    func testParsePlaceDetailsReadsFieldsAndRejectsUnknown() {
        guard case .ok(let args) = PlacesArgParsers.parsePlaceDetails(
            ["placeId": "p1", "sessionToken": "tok", "fields": ["name", "viewport"]]
        ) else {
            XCTFail("Expected ok for known fields")
            return
        }
        XCTAssertEqual(args.fields, ["name", "viewport"], "fields")
        guard case .err = PlacesArgParsers.parsePlaceDetails(
            ["placeId": "p1", "sessionToken": "tok", "fields": ["photos"]]
        ) else {
            XCTFail("unknown field 'photos' must be rejected, not silently billed")
            return
        }
    }

    func testParseSearchNearbyReadsAllArgs() {
        guard case .ok(let args) = PlacesArgParsers.parseSearchNearby([
            "center": ["lat": 43.65, "lng": -79.38],
            "radiusMeters": 500,
            "types": ["gas_station"],
            "maxResults": 5,
            "rankBy": "distance",
        ]) else {
            XCTFail("Expected ok for valid nearby args")
            return
        }
        XCTAssertEqual(args.radiusMeters, 500, "radius")
        XCTAssertEqual(args.types, ["gas_station"], "types")
        XCTAssertEqual(args.maxResults, 5, "maxResults")
        XCTAssertTrue(args.rankByDistance, "rankBy distance")
    }

    func testParseSearchNearbyRejectsBadArgs() {
        let valid: [String: Any] = ["center": ["lat": 43.65, "lng": -79.38], "radiusMeters": 500]
        let bad: [String: [String: Any]] = [
            "no center": ["radiusMeters": 500],
            "radius 0": valid.merging(["radiusMeters": 0]) { _, new in new },
            "maxResults 21": valid.merging(["maxResults": 21]) { _, new in new },
            "rankBy rating": valid.merging(["rankBy": "rating"]) { _, new in new },
        ]
        for (why, args) in bad {
            guard case .err = PlacesArgParsers.parseSearchNearby(args) else {
                XCTFail("expected INVALID_ARGUMENT for: \(why)")
                continue
            }
        }
    }

    func testParseAutocompleteCancelPreviousMustBeBool() {
        guard case .ok(let off) = autocomplete([:]), case .ok(let on) = autocomplete(["cancelPrevious": true]) else {
            XCTFail("Expected ok with and without cancelPrevious")
            return
        }
        XCTAssertFalse(off.cancelPrevious, "absent cancelPrevious must mean no cancellation")
        XCTAssertTrue(on.cancelPrevious, "cancelPrevious true")
        guard case .err = autocomplete(["cancelPrevious": 1]) else {
            XCTFail("cancelPrevious 1 (not a bool) must be INVALID_ARGUMENT")
            return
        }
    }

    func testParseAutocompleteGoogleDocumentedBoundaries() {
        let codes = ["CA", "IN", "US", "GB", "FR", "DE", "IT", "ES", "MX", "BR", "AU", "NZ", "JP", "AE", "SG", "ZA"]
        var maxCircle = circle
        maxCircle["radiusMeters"] = 50000.0
        var overCircle = circle
        overCircle["radiusMeters"] = 50000.1
        let accepted: [String: [String: Any]] = [
            "15 countries": ["countries": Array(codes.prefix(15))],
            "radius exactly 50000": ["locationBias": maxCircle],
            "lat 90 / lng 180": ["origin": ["lat": 90.0, "lng": 180.0]],
            "rectangle across the 180th meridian": ["locationRestriction": [
                "type": "rectangle",
                "southwest": ["lat": -20.0, "lng": 170.0],
                "northeast": ["lat": -10.0, "lng": -170.0],
            ]],
        ]
        for (why, extra) in accepted {
            guard case .ok = autocomplete(extra) else {
                XCTFail("expected OK for: \(why)")
                continue
            }
        }
        let rejected: [String: [String: Any]] = [
            "16 countries": ["countries": codes],
            "alpha-3 country": ["countries": ["CAN"]],
            "radius 50000.1": ["locationBias": overCircle],
            "lat 90.0001": ["origin": ["lat": 90.0001, "lng": 0.0]],
        ]
        for (why, extra) in rejected {
            guard case .err = autocomplete(extra) else {
                XCTFail("expected INVALID_ARGUMENT for: \(why)")
                continue
            }
        }
    }
}
