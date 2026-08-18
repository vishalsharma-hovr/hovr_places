import '../models/place_details.dart';
import '../models/place_prediction.dart';
import '../models/places_exception.dart';

Map<String, Object> autocompleteArgs({
  required String query,
  required String sessionToken,
  List<String>? countries,
  String? language,
}) {
  return <String, Object>{
    'query': query,
    'sessionToken': sessionToken,
    'countries': ?countries,
    'language': ?language,
  };
}

Map<String, Object> placeDetailsArgs({
  required String placeId,
  required String sessionToken,
}) {
  return <String, Object>{'placeId': placeId, 'sessionToken': sessionToken};
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
