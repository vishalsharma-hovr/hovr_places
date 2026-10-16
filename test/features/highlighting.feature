Feature: Match highlighting
  Native sends which parts of the primary text match the query.

  Scenario: Match ranges are mapped from native
    Given native returns "Union Station" with match 0, 5
    When the app searches for "union"
    Then the prediction has primaryMatches (0, 5)

  Scenario: Out-of-range match ranges are dropped
    Given native returns "Union" with matches 0, 3 and 2, 99
    When the app searches for "uni"
    Then the prediction has primaryMatches (0, 3) only

  Scenario: Matched text is shown in bold
    Given native returns "Union Station" with match 0, 5
    When the rider types "union" and waits 300 ms
    Then "Union" is bold and " Station" is not
