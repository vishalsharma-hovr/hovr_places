import '../channels/places_payload.dart';
import 'place_details_field.dart';

/// One autocomplete suggestion from Google Places.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
    this.distanceMeters,
    this.types = const <String>[],
    this.primaryMatches = const <(int, int)>[],
  });

  factory PlacePrediction.fromMap(Map<String, Object?> map) {
    final primaryText = requiredString(map['primaryText'], 'primaryText');
    return PlacePrediction(
      placeId: requiredString(map['placeId'] ?? map['place_id'], 'placeId'),
      primaryText: primaryText,
      secondaryText: optionalString(map['secondaryText']),
      fullText: requiredString(map['fullText'], 'fullText'),
      distanceMeters: optionalInt(map['distanceMeters'], 'distanceMeters'),
      types: stringList(map['types'], 'types'),
      primaryMatches: parseMatches(
        map['primaryMatches'],
        primaryText.length,
        'primaryMatches',
      ),
    );
  }

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;

  /// Straight-line distance from the request `origin`, in meters. Null when
  /// no origin was sent or Google returned none. Not driving distance.
  final int? distanceMeters;

  /// Google place types, e.g. `airport`, `street_address`.
  final List<String> types;

  /// `(offset, length)` ranges of [primaryText] that match the query, for
  /// bolding. Offsets are UTF-16 code units, like Dart strings.
  final List<(int, int)> primaryMatches;

  bool get isAirport => types.contains(placesAirportType);

  Map<String, Object> toMap() {
    return <String, Object>{
      'placeId': placeId,
      'primaryText': primaryText,
      'secondaryText': secondaryText,
      'fullText': fullText,
      'distanceMeters': ?distanceMeters,
      'types': types,
      'primaryMatches': [
        for (final (offset, length) in primaryMatches) [offset, length],
      ],
    };
  }
}
