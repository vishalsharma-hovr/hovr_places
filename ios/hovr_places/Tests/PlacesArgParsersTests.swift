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
}
