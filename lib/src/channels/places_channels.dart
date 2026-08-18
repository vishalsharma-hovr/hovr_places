/// Stable method-channel names and method identifiers for `hovr_places`.
class PlacesChannels {
  PlacesChannels._();

  static const name = 'com.hovr/places';

  static const autocomplete = 'autocomplete';
  static const placeDetails = 'placeDetails';
  static const endSession = 'endSession';
}

/// Stable [PlatformException] / native `result.error` codes.
class PlacesErrorCodes {
  PlacesErrorCodes._();

  static const invalidArgument = 'INVALID_ARGUMENT';
  static const missingApiKey = 'MISSING_API_KEY';
  static const placeError = 'PLACE_ERROR';
  static const unimplemented = 'UNIMPLEMENTED';
}
