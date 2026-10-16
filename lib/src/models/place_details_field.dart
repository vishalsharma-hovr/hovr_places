/// Optional place-details fields. Each one is billed by Google, so request
/// only what the screen needs. id, coordinates, address and types are always
/// returned.
enum PlaceDetailsField {
  /// Display name, e.g. "Toronto Pearson International Airport".
  name,

  /// City, postal code, province… for fare zones and taxes.
  addressComponents,

  /// Bounds to zoom the map to.
  viewport,

  /// Plus code, for places without a street address.
  plusCode,
}

/// Google type that marks an airport, in predictions and details.
const placesAirportType = 'airport';
