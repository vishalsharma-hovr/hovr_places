Feature: Place details
  After the rider picks a prediction, the app fetches coordinates and address.

  Scenario: Coordinates and address are mapped from the native result
    Given native returns place "p1" at 43.65, -79.38 in "Toronto"
    When the app fetches details for "p1"
    Then the app gets latitude 43.65, longitude -79.38 and address "Toronto"

  Scenario: String coordinates are accepted
    Given native returns latitude as the string "43.65"
    When the app fetches details for "p1"
    Then the app gets latitude 43.65

  Scenario: A place without coordinates is rejected
    Given native returns place "p1" without "lat"
    When the app fetches details for "p1"
    Then the fetch fails with "INVALID_ARGUMENT"

  Scenario: Out-of-range coordinates are rejected
    Given native returns place "p1" at -180, -180
    When the app fetches details for "p1"
    Then the fetch fails with "INVALID_ARGUMENT"

  Scenario: An empty place id is rejected without calling native
    When the app fetches details for "  "
    Then the fetch fails with "INVALID_ARGUMENT"
    And native receives no call
