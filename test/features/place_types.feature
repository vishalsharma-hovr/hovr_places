Feature: Place types and region
  Type filters narrow autocomplete (e.g. airports only), region code tunes
  formatting and ranking, and airports are flagged for a terminal picker.

  Scenario: Type filters are sent to native
    When the app searches for "pearson" with types "airport"
    Then native receives types "airport"

  Scenario: More than 5 type filters are rejected
    When the app searches with 6 type filters
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call

  Scenario: Region code from the config is sent with autocomplete
    Given the config region code is "IN"
    When the app searches for "connaught"
    Then native receives regionCode "IN"

  Scenario: A bad region code is rejected
    When the app searches with region code "IND"
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call

  Scenario: An airport prediction is flagged
    Given native returns "Toronto Pearson" with types "airport"
    When the app searches for "pearson"
    Then the prediction isAirport is true
