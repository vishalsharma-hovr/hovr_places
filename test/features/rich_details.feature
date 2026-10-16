Feature: Rich place details
  The caller picks extra billed fields; base fields always come back.

  Scenario: Requested fields are sent to native
    When the app fetches details for "p1" with fields name and viewport
    Then native receives fields "name", "viewport"

  Scenario: No extra fields sends no fields list
    When the app fetches details for "p1" without fields
    Then native receives no "fields" argument

  Scenario: Name, address components, viewport and plus code are mapped
    Given native returns all optional fields for "p1"
    When the app fetches details for "p1" with every field
    Then the app gets the name, city, viewport and plus code

  Scenario: An airport place is flagged
    Given native returns place "p1" with types "airport"
    When the app fetches details for "p1"
    Then the place isAirport is true
