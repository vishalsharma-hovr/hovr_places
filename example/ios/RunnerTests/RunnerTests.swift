import XCTest
@testable import hovr_places

class RunnerTests: XCTestCase {
  func testParseAutocompleteRejectsMissingQuery() {
    let result = PlacesArgParsers.parseAutocomplete(["sessionToken": "abc-123"])
    guard case .err = result else {
      XCTFail("Expected INVALID_ARGUMENT equivalent")
      return
    }
  }

  func testApiKeyNormalizerRejectsPlaceholders() {
    XCTAssertEqual(PlacesApiKey.normalized("YOUR_API_KEY"), "")
  }
}
