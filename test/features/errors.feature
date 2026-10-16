Feature: Error mapping
  Native failures reach the app as PlacesException with a stable code.

  Scenario Outline: Native error codes reach the app unchanged
    Given native fails with "<code>"
    When the app searches for "union"
    Then the search fails with "<code>"

    Examples:
      | code             |
      | MISSING_API_KEY  |
      | PLACE_ERROR      |
      | INVALID_ARGUMENT |
      | CANCELLED        |

  Scenario: Plugin not registered maps to UNIMPLEMENTED
    Given no native plugin is registered
    When the app searches for "union"
    Then the search fails with "UNIMPLEMENTED"

  Scenario: An unknown error maps to PLACE_ERROR without leaking details
    Given a non-platform error "secret AIza123"
    When it is converted to a PlacesException
    Then the code is "PLACE_ERROR" and the message does not contain "AIza"

  Scenario: The native error code is exposed for support
    Given native fails with "PLACE_ERROR" and native code 9011
    When the app searches for "union"
    Then the exception's nativeCode is 9011
