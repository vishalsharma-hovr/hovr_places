Feature: Autocomplete field widget
  HovrPlacesAutocompleteField debounces typing, shows predictions and errors,
  and owns its session unless the app passes one in.

  Scenario: Typing shows predictions after the debounce
    Given native returns "Union Station"
    When the rider types "union" and waits 300 ms
    Then "Union Station" is shown in the list

  Scenario: Typing faster than the debounce sends one request
    When the rider types "u", "un", "uni" within 300 ms
    Then native receives exactly one autocomplete call with query "uni"

  Scenario: Clearing the text clears the results without calling native
    Given the list shows "Union Station"
    When the rider clears the text
    Then the list is empty
    And native receives no new autocomplete call

  Scenario: Tapping a prediction reports it to the app
    Given the list shows "Union Station"
    When the rider taps "Union Station"
    Then onSelected receives place id "p1"

  Scenario: A native error is shown under the field
    Given native fails with "PLACE_ERROR" and message "Places SDK request failed"
    When the rider types "union" and waits 300 ms
    Then "Places SDK request failed" is shown

  Scenario: Leaving the screen closes the field's own session
    Given the field created its own session and searched once
    When the field is removed from the screen
    Then native receives "endSession" with the same token

  Scenario: A session passed in by the app is not closed by the field
    Given the app passes session "app-sess" to the field
    When the field is removed from the screen
    Then native receives no "endSession" call

  Scenario: A slow old response does not replace newer results
    Given native answers "toro" slowly and "toronto" quickly
    When the rider types "toro" then "toronto"
    And the slow "toro" answer arrives last
    Then the list still shows the "toronto" results

  Scenario: A query shorter than the minimum length is not sent
    Given the minimum query length is 2
    When the rider types "u" and waits 300 ms
    Then native receives no autocomplete call

  Scenario: A search with no matches shows the no-results message
    Given native returns no predictions
    When the rider types "zzzz" and waits 300 ms
    Then "No places found" is shown

  Scenario: The clear button empties the field and the list
    Given the list shows "Union Station"
    When the rider taps the clear button
    Then the field is empty
    And the list is empty

  Scenario: The field's config does not change the app-wide config
    Given the field is given countries "IN"
    When the field is shown
    Then the app-wide config countries are still empty

  Scenario: A loading bar is shown while a search is in flight
    Given native has not answered yet
    When the rider types "union" and waits 300 ms
    Then a loading bar is shown
    And it disappears once native answers

  Scenario: A custom itemBuilder renders each prediction
    Given the app passes an itemBuilder that shows "-> <primary text>"
    When the rider types "union" and waits 300 ms
    Then "-> Union Station" is shown

  Scenario: A failed endSession while leaving the screen does not crash
    Given native fails every call with "PLACE_ERROR"
    When the field is removed from the screen
    Then no error reaches the app

  Scenario: The field sends its origin and sorts by distance
    Given the field has origin 43.65, -79.38 and sortByDistance enabled
    And native returns "Far" at 5000 m and "Near" at 300 m
    When the rider types "union" and waits 300 ms
    Then native receives the origin
    And "Near" is listed above "Far"

  Scenario: Distances are shown as meters under 1 km and kilometers above
    Given native returns "Near" at 850 m and "Far" at 1234 m
    When the rider types "union" and waits 300 ms
    Then "850 m" and "1.2 km" are shown

  Scenario: The idle builder is shown before the rider types
    Given the app passes an idleBuilder showing "Home"
    When the field is shown
    Then "Home" is shown

  Scenario: The idle builder is hidden once a search runs
    Given the app passes an idleBuilder showing "Home"
    When the rider types "union" and waits 300 ms
    Then "Home" is not shown

  Scenario: An airport prediction shows a plane icon
    Given native returns "Toronto Pearson" with types "airport"
    When the rider types "pearson" and waits 300 ms
    Then a plane icon is shown

  Scenario: The field opts in to native cancellation
    When the rider types "union" and waits 300 ms
    Then native receives cancelPrevious true
