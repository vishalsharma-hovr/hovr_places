Feature: Autocomplete
  The app sends a query and gets back typed predictions.

  Scenario: Predictions are mapped from the native result
    Given native returns one prediction "Union Station, Toronto"
    When the app searches for "union station"
    Then the app gets 1 prediction with place id "p1" and primary text "Union Station"

  Scenario: The query is trimmed before it is sent
    When the app searches for "  union  "
    Then native receives the query "union"

  Scenario: By default no country filter is sent
    Given the default config
    When the app searches for "union" without countries
    Then native receives an empty countries list

  Scenario: Default countries come from the config
    Given the config countries are "CA"
    When the app searches for "union" without countries
    Then native receives countries "CA" and no language

  Scenario: Per-call countries and language override the config
    Given the config countries are "CA"
    When the app searches for "union" with countries "IN" and language "hi"
    Then native receives countries "IN" and language "hi"

  Scenario: An empty query is rejected without calling native
    When the app searches for "   "
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call

  Scenario: A missing predictions list means no results
    Given native returns a result without "predictions"
    When the app searches for "zzzz"
    Then the app gets an empty list

  Scenario: A malformed prediction is reported as INVALID_ARGUMENT
    Given native returns a prediction without "primaryText"
    When the app searches for "union"
    Then the search fails with "INVALID_ARGUMENT"

  Scenario: Native cancellation is off unless asked for
    When the app searches for "union" without cancelPrevious
    Then native receives no "cancelPrevious" argument
