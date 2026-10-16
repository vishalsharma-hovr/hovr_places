Feature: Sort predictions by distance
  The app passes the rider's or driver's location as origin, native returns
  distanceMeters per prediction, and sortByDistance orders them nearest first.
  Distance is straight-line, not driving distance.

  Scenario: The origin is sent to native
    Given the rider is at 43.6453, -79.3806
    When the app searches for "union" with that origin
    Then native receives origin lat 43.6453 and lng -79.3806

  Scenario: Distance is mapped onto each prediction
    Given native returns "Union Station" with distanceMeters 1200
    When the app searches for "union" with an origin
    Then the prediction has distanceMeters 1200

  Scenario: Predictions are sorted nearest first
    Given native returns predictions at 5000 m, 300 m and 1200 m
    When the app searches with sortByDistance enabled
    Then the predictions come back as 300 m, 1200 m, 5000 m

  Scenario: Predictions without a distance go last
    Given native returns predictions at 800 m, no distance, and 200 m
    When the app searches with sortByDistance enabled
    Then the predictions come back as 200 m, 800 m, no distance

  Scenario: Equal distances keep Google's order
    Given native returns A, B and C all at 500 m
    When the app searches with sortByDistance enabled
    Then the predictions come back as A, B, C

  Scenario: Without sortByDistance Google's order is kept
    Given native returns predictions at 5000 m, 300 m and 1200 m
    When the app searches without sortByDistance
    Then the predictions come back as 5000 m, 300 m, 1200 m

  Scenario: An out-of-range origin is rejected without calling native
    When the app searches with origin 95, 0
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call
