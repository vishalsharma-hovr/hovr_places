Feature: Location bias and restriction
  locationBias prefers results inside an area; locationRestriction returns
  only results inside it (e.g. a service area). Google allows only one.

  Scenario: A circular bias is sent to native
    Given a circle of 5000 m around 43.65, -79.38
    When the app searches for "union" with that circle as locationBias
    Then native receives locationBias type "circle" with that center and radius

  Scenario: A rectangular restriction is sent to native
    Given a rectangle from 43.58, -79.64 to 43.86, -79.12
    When the app searches for "union" with that rectangle as locationRestriction
    Then native receives locationRestriction type "rectangle" with those corners

  Scenario: Bias and restriction together are rejected
    When the app searches with both locationBias and locationRestriction
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call

  Scenario: A radius over 50 km is rejected
    When the app searches with a 60000 m circle as locationBias
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call

  Scenario: A rectangle with southwest north of northeast is rejected
    When the app searches with a rectangle whose southwest is north of its northeast
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call
