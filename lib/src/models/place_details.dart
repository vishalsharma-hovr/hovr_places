import '../channels/places_payload.dart';

/// Coordinates and address for a selected place.
class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.types = const <String>[],
  });

  factory PlaceDetails.fromMap(Map<String, Object?> map) {
    return PlaceDetails(
      placeId: requiredString(map['placeId'] ?? map['place_id'], 'placeId'),
      latitude: requiredDouble(map['lat'] ?? map['latitude'], 'lat'),
      longitude: requiredDouble(
        map['lng'] ?? map['longitude'] ?? map['long'],
        'lng',
      ),
      formattedAddress: optionalString(map['formattedAddress']),
      types: stringList(map['types'], 'types'),
    );
  }

  final String placeId;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final List<String> types;

  Map<String, Object> toMap() {
    return <String, Object>{
      'placeId': placeId,
      'lat': latitude,
      'lng': longitude,
      'formattedAddress': formattedAddress,
      'types': types,
    };
  }
}
