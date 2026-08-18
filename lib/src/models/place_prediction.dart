import '../channels/places_payload.dart';

/// One autocomplete suggestion from Google Places.
class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
  });

  factory PlacePrediction.fromMap(Map<String, Object?> map) {
    return PlacePrediction(
      placeId: requiredString(map['placeId'] ?? map['place_id'], 'placeId'),
      primaryText: requiredString(map['primaryText'], 'primaryText'),
      secondaryText: optionalString(map['secondaryText']),
      fullText: requiredString(map['fullText'], 'fullText'),
    );
  }

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;

  Map<String, Object> toMap() {
    return <String, Object>{
      'placeId': placeId,
      'primaryText': primaryText,
      'secondaryText': secondaryText,
      'fullText': fullText,
    };
  }
}
