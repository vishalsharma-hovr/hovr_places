Feature: Places session lifecycle
  Dart owns a UUID session token so Google bills autocomplete and
  place details as one session. Native drops its SDK token on endSession.

  Scenario: A new session gets a UUID v4 token
    Given a new Places session
    Then its token is a 36-character UUID v4

  Scenario: Two sessions never share a token
    Given two new Places sessions
    Then their tokens are different

  Scenario: Closing a session tells native to drop it
    Given an open session "sess-1"
    When the session is closed
    Then native receives "endSession" with token "sess-1"
    And the session is marked closed

  Scenario: Closing a session twice only calls native once
    Given an open session "sess-1"
    When the session is closed twice
    Then native receives "endSession" exactly once

  Scenario: A closed session cannot be used for autocomplete
    Given a closed session "sess-1"
    When the app searches for "union"
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no autocomplete call

  Scenario: Autocomplete and details share the same session token
    Given an open session "sess-1"
    When the app searches for "union" and fetches details for "p1"
    Then both native calls carry token "sess-1"
