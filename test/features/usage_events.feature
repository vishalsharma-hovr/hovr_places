Feature: Usage events
  onUsage reports every native call, for analytics and cost tracking.

  Scenario: A successful call reports a usage event
    Given the app listens to onUsage
    When the app searches for "union" in session "sess-1"
    Then one event is reported for "autocomplete" in "sess-1" with no error

  Scenario: A failed call reports its error code
    Given the app listens to onUsage
    And native fails with "PLACE_ERROR"
    When the app searches for "union"
    Then the event has error code "PLACE_ERROR"

  Scenario: Nearby calls report no session token
    Given the app listens to onUsage
    When the app searches nearby
    Then the event for "searchNearby" has no session token
