import '../models/place_details.dart';
import '../models/place_details_field.dart';
import '../models/places_geo.dart';
import '../models/place_prediction.dart';
import '../models/places_exception.dart';

Map<String, Object> autocompleteArgs({
  required String query,
  required String sessionToken,
  List<String>? countries,
  String? language,
  PlacesLatLng? origin,
  PlacesArea? locationBias,
  PlacesArea? locationRestriction,
  List<String>? types,
  String? regionCode,
  bool cancelPrevious = false,
}) {
  return <String, Object>{
    'query': query,
    'sessionToken': sessionToken,
    'countries': ?countries,
    'language': ?language,
    'origin': ?origin?.toMap(),
    'locationBias': ?locationBias?.toMap(),
    'locationRestriction': ?locationRestriction?.toMap(),
    'types': ?types,
    'regionCode': ?regionCode,
    if (cancelPrevious) 'cancelPrevious': true,
  };
}

/// Google allows at most 15 autocomplete countries (`includedRegionCodes`).
const maxAutocompleteCountries = 15;

void checkCountries(List<String> countries) {
  final valid = RegExp(r'^[A-Za-z]{2}$');
  if (countries.length > maxAutocompleteCountries ||
      countries.any((c) => !valid.hasMatch(c.trim()))) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message:
          'countries must be up to $maxAutocompleteCountries 2-letter codes, '
          'got $countries',
    );
  }
}

/// Google allows at most 5 autocomplete type filters.
const maxAutocompleteTypes = 5;

/// Google returns at most 20 nearby places.
const maxNearbyResults = 20;

void checkTypes(List<String>? types, int max) {
  if (types == null) return;
  if (types.length > max || types.any((t) => t.trim().isEmpty)) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message: 'types must be 1–$max non-empty strings, got $types',
    );
  }
}

void checkRegionCode(String? regionCode) {
  if (regionCode == null) return;
  if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(regionCode)) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message: 'regionCode must be a 2-letter CLDR code, got "$regionCode"',
    );
  }
}

List<String> fieldNames(Set<PlaceDetailsField> fields) => [
  for (final field in PlaceDetailsField.values)
    if (fields.contains(field)) field.name,
];

Map<String, Object> searchNearbyArgs({
  required PlacesCircle area,
  List<String>? types,
  int? maxResults,
  bool rankByDistance = false,
  Set<PlaceDetailsField> fields = const <PlaceDetailsField>{},
  String? regionCode,
}) {
  return <String, Object>{
    'center': area.center.toMap(),
    'radiusMeters': area.radiusMeters,
    'types': ?types,
    'maxResults': ?maxResults,
    'rankBy': rankByDistance ? 'distance' : 'popularity',
    if (fields.isNotEmpty) 'fields': fieldNames(fields),
    'regionCode': ?regionCode,
  };
}

/// Throws INVALID_ARGUMENT before a bad location reaches native.
void checkLocationArgs({
  PlacesLatLng? origin,
  PlacesArea? locationBias,
  PlacesArea? locationRestriction,
}) {
  if (locationBias != null && locationRestriction != null) {
    throw const PlacesException(
      code: PlacesException.invalidArgument,
      message: 'Pass locationBias or locationRestriction, not both',
    );
  }
  if (origin != null) checkLatLng(origin, 'origin');
  if (locationBias != null) checkArea(locationBias, 'locationBias');
  if (locationRestriction != null) {
    checkArea(locationRestriction, 'locationRestriction');
  }
}

void checkLatLng(PlacesLatLng point, String key) {
  // Written as !(<=) so NaN is rejected too.
  if (!(point.latitude.abs() <= 90 && point.longitude.abs() <= 180)) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message: '$key out of range: ${point.latitude}, ${point.longitude}',
    );
  }
}

void checkArea(PlacesArea area, String key) {
  switch (area) {
    case PlacesCircle(:final center, :final radiusMeters):
      checkLatLng(center, '$key.center');
      if (!(radiusMeters > 0 && radiusMeters <= 50000)) {
        throw PlacesException(
          code: PlacesException.invalidArgument,
          message: '$key.radiusMeters must be in (0, 50000], got $radiusMeters',
        );
      }
    case PlacesRectangle(:final southwest, :final northeast):
      checkLatLng(southwest, '$key.southwest');
      checkLatLng(northeast, '$key.northeast');
      if (southwest.latitude > northeast.latitude) {
        throw PlacesException(
          code: PlacesException.invalidArgument,
          message: '$key.southwest must be south of $key.northeast',
        );
      }
  }
}

/// Nearest first; predictions without a distance go last. Stable, so equal
/// distances keep Google's relevance order.
List<PlacePrediction> sortByDistancePredictions(
  List<PlacePrediction> predictions,
) {
  final indexed = predictions.indexed.toList();
  indexed.sort((a, b) {
    final da = a.$2.distanceMeters;
    final db = b.$2.distanceMeters;
    if (da != db) {
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    }
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, prediction) in indexed) prediction];
}

Map<String, Object> placeDetailsArgs({
  required String placeId,
  required String sessionToken,
  Set<PlaceDetailsField> fields = const <PlaceDetailsField>{},
  String? regionCode,
}) {
  return <String, Object>{
    'placeId': placeId,
    'sessionToken': sessionToken,
    if (fields.isNotEmpty) 'fields': fieldNames(fields),
    'regionCode': ?regionCode,
  };
}

Map<String, Object> endSessionArgs({required String sessionToken}) {
  return <String, Object>{'sessionToken': sessionToken};
}

Map<String, Object?> asStringKeyedMap(Object? value, String key) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  throw PlacesException(
    code: PlacesException.invalidArgument,
    message: 'Expected map at $key',
  );
}

String requiredString(Object? value, String key) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw PlacesException(
    code: PlacesException.invalidArgument,
    message: 'Expected non-empty String at $key',
  );
}

String optionalString(Object? value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  return value.toString().trim();
}

double requiredDouble(Object? value, String key) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw PlacesException(
    code: PlacesException.invalidArgument,
    message: 'Expected number at $key',
  );
}

int? optionalInt(Object? value, String key) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num && value.isFinite) return value.round();
  throw PlacesException(
    code: PlacesException.invalidArgument,
    message: 'Expected number at $key',
  );
}

List<String> stringList(Object? value, String key) {
  if (value == null) return const <String>[];
  if (value is! List) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message: 'Expected List at $key',
    );
  }
  return value
      .map((Object? item) {
        if (item == null) return '';
        return item.toString();
      })
      .where((item) => item.isNotEmpty)
      .toList();
}

List<PlacePrediction> parsePredictions(Object? raw) {
  final map = asStringKeyedMap(raw, 'autocomplete result');
  final predictionsRaw = map['predictions'];
  if (predictionsRaw == null) return const <PlacePrediction>[];
  if (predictionsRaw is! List) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message: 'Expected List at predictions',
    );
  }
  return predictionsRaw
      .map(
        (Object? item) =>
            PlacePrediction.fromMap(asStringKeyedMap(item, 'prediction')),
      )
      .toList();
}

PlaceDetails parsePlaceDetails(Object? raw) {
  return PlaceDetails.fromMap(asStringKeyedMap(raw, 'placeDetails result'));
}

List<T> mapList<T>(
  Object? raw,
  String key,
  T Function(Map<String, Object?> map) parse,
) {
  if (raw is! List) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message: 'Expected List at $key',
    );
  }
  return [for (final item in raw) parse(asStringKeyedMap(item, key))];
}

PlacesLatLng parseLatLngMap(Object? raw, String key) {
  final map = asStringKeyedMap(raw, key);
  final point = PlacesLatLng(
    requiredDouble(map['lat'], '$key.lat'),
    requiredDouble(map['lng'], '$key.lng'),
  );
  checkLatLng(point, key);
  return point;
}

PlacesRectangle parseRectangle(Object? raw, String key) {
  final map = asStringKeyedMap(raw, key);
  return PlacesRectangle(
    southwest: parseLatLngMap(map['southwest'], '$key.southwest'),
    northeast: parseLatLngMap(map['northeast'], '$key.northeast'),
  );
}

/// Keeps only well-formed `[offset, length]` ranges inside the text. Bad
/// ranges are dropped rather than failing the search: bolding is cosmetic.
List<(int, int)> parseMatches(Object? raw, int textLength, String key) {
  if (raw == null) return const <(int, int)>[];
  if (raw is! List) {
    throw PlacesException(
      code: PlacesException.invalidArgument,
      message: 'Expected List at $key',
    );
  }
  return [
    for (final item in raw)
      if (item case [
        final int offset,
        final int length,
      ] when offset >= 0 && length > 0 && offset + length <= textLength)
        (offset, length),
  ];
}

List<PlaceDetails> parsePlaces(Object? raw) {
  final map = asStringKeyedMap(raw, 'searchNearby result');
  final places = map['places'];
  if (places == null) return const <PlaceDetails>[];
  return mapList(places, 'places', PlaceDetails.fromMap);
}
