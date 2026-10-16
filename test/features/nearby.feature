Feature: Nearby search and current location
  searchNearby finds places in a circle (pickup landmarks, EV chargers);
  nearestPlace turns the rider's position into the closest place.

  Scenario: Nearby search sends center, radius, types and ranking
    When the app searches 500 m around 43.65, -79.38 for "electric_vehicle_charging_station" ranked by distance
    Then native receives that center, radius, types and rankBy "distance"

  Scenario: Nearby places are mapped
    Given native returns 2 nearby places
    When the app searches nearby
    Then the app gets 2 places with coordinates

  Scenario: maxResults above 20 is rejected
    When the app searches nearby with maxResults 21
    Then the search fails with "INVALID_ARGUMENT"
    And native receives no call

  Scenario: Nearest place asks for one result ranked by distance
    When the app asks for the nearest place to 43.65, -79.38
    Then native receives maxResults 1, rankBy "distance" and radius 100 m

  Scenario: Nearest place is null when nothing is nearby
    Given native returns no nearby places
    When the app asks for the nearest place
    Then the app gets null
