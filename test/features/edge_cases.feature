Feature: Edge cases from Google's documented limits
  Boundaries and inputs taken from the Autocomplete (New), Nearby Search (New)
  and PlacesStatusCodes documentation, plus real rider/driver input.

  Scenario: More than 15 countries are rejected
    When the app searches with 16 countries
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call

  Scenario: A country code that is not 2 letters is rejected
    When the app searches with countries "CAN"
    Then the search fails with "INVALID_ARGUMENT"

  Scenario: Exactly 15 countries are accepted
    When the app searches with 15 countries
    Then native receives 15 countries

  Scenario: A rectangle crossing the 180° meridian is accepted
    When the app restricts to a rectangle from lng 170 to lng -170
    Then native receives that rectangle unchanged

  Scenario: A 50 km circle is accepted and 50.0001 km is rejected
    When the app restricts to a 50000 m circle, then a 50000.1 m circle
    Then the first is sent and the second fails with "INVALID_ARGUMENT"

  Scenario: Poles and the date line are valid coordinates
    When the app sends origins at lat 90, lat -90 and lng 180
    Then all three reach native
    And lat 90.0001 fails with "INVALID_ARGUMENT"

  Scenario Outline: Non-English and unusual queries reach native unchanged
    When the app searches for "<query>"
    Then native receives exactly "<query>"

    Examples:
      | query               |
      | दिल्ली रेलवे स्टेशन   |
      | Montréal–Trudeau    |
      | مطار دبي            |
      | 🚉 Union            |
      | O'Hare & 5th Ave.   |

  Scenario: A 1000-character query is sent without crashing
    When the app searches for a 1000-character query
    Then native receives all 1000 characters

  Scenario Outline: Google's native status codes reach the app
    Given native fails with "PLACE_ERROR" and native code <nativeCode>
    When the app searches for "union"
    Then the exception's nativeCode is <nativeCode>

    Examples:
      | nativeCode | meaning           |
      | 9010       | OVER_QUERY_LIMIT  |
      | 9011       | REQUEST_DENIED    |
      | 9012       | INVALID_REQUEST   |
      | 9013       | NOT_FOUND         |
      | 15         | TIMEOUT           |
      | 7          | NETWORK_ERROR     |

  Scenario: A place that no longer exists fails details with NOT_FOUND
    Given native fails details with "PLACE_ERROR" and native code 9013
    When the app fetches details for "stale-id"
    Then the fetch fails with "PLACE_ERROR" and nativeCode 9013

  Scenario: Concurrent searches each get their own answer
    Given native echoes each query back as the prediction
    When the app runs 20 searches at once
    Then every search gets the prediction for its own query

  Scenario: Two sessions keep separate tokens
    When the app searches in session "rider-pickup" and "rider-dropoff" at once
    Then each native call carries its own session token

  Scenario: Highlighting survives emoji before the match
    Given native returns "🚉 Union" with match 3, 5
    When the rider types "union" and waits 300 ms
    Then "Union" is bold

  Scenario Outline: Distance labels at the unit boundary
    Then <meters> m is labelled "<label>"

    Examples:
      | meters | label   |
      | 0      | 0 m     |
      | 999    | 999 m   |
      | 1000   | 1.0 km  |
      | 9999   | 10.0 km |
