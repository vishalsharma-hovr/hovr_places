import '../channels/places_payload.dart';
import 'place_address_component.dart';
import 'place_details_field.dart';
import 'places_exception.dart';
import 'places_geo.dart';

/// Coordinates and address for a selected place.
class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.types = const <String>[],
    this.name,
    this.addressComponents = const <PlaceAddressComponent>[],
    this.viewport,
    this.plusCode,
  });

  factory PlaceDetails.fromMap(Map<String, Object?> map) {
    final latitude = requiredDouble(map['lat'] ?? map['latitude'], 'lat');
    final longitude = requiredDouble(
      map['lng'] ?? map['longitude'] ?? map['long'],
      'lng',
    );
    // Written as !(<=) so NaN is rejected too.
    if (!(latitude.abs() <= 90 && longitude.abs() <= 180)) {
      throw PlacesException(
        code: PlacesException.invalidArgument,
        message: 'Coordinates out of range: $latitude, $longitude',
      );
    }
    final components = map['addressComponents'];
    final viewport = map['viewport'];
    final plusCode = map['plusCode'];
    return PlaceDetails(
      placeId: requiredString(map['placeId'] ?? map['place_id'], 'placeId'),
      latitude: latitude,
      longitude: longitude,
      formattedAddress: optionalString(map['formattedAddress']),
      types: stringList(map['types'], 'types'),
      name: _nonEmpty(optionalString(map['name'])),
      addressComponents: components == null
          ? const <PlaceAddressComponent>[]
          : mapList(
              components,
              'addressComponents',
              PlaceAddressComponent.fromMap,
            ),
      viewport: viewport == null ? null : parseRectangle(viewport, 'viewport'),
      plusCode: plusCode == null
          ? null
          : PlacePlusCode.fromMap(asStringKeyedMap(plusCode, 'plusCode')),
    );
  }

  final String placeId;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final List<String> types;

  /// Only set when [PlaceDetailsField.name] was requested.
  final String? name;

  /// Only set when [PlaceDetailsField.addressComponents] was requested.
  final List<PlaceAddressComponent> addressComponents;

  /// Only set when [PlaceDetailsField.viewport] was requested.
  final PlacesRectangle? viewport;

  /// Only set when [PlaceDetailsField.plusCode] was requested.
  final PlacePlusCode? plusCode;

  PlacesLatLng get location => PlacesLatLng(latitude, longitude);

  bool get isAirport => types.contains(placesAirportType);

  /// Name of the first component with [type], e.g. `locality` (city) or
  /// `postal_code`. Needs [PlaceDetailsField.addressComponents].
  String? component(String type) {
    for (final part in addressComponents) {
      if (part.types.contains(type)) return part.name;
    }
    return null;
  }

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

String? _nonEmpty(String value) => value.isEmpty ? null : value;
