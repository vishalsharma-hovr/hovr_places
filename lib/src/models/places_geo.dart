/// A WGS84 coordinate passed to native autocomplete.
class PlacesLatLng {
  const PlacesLatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  Map<String, Object> toMap() => <String, Object>{
    'lat': latitude,
    'lng': longitude,
  };
}

/// An area for autocomplete `locationBias` (prefer results inside) or
/// `locationRestriction` (only results inside).
sealed class PlacesArea {
  const PlacesArea();

  Map<String, Object> toMap();
}

/// Circle around [center]. Google allows a radius of 0–50 000 m.
class PlacesCircle extends PlacesArea {
  const PlacesCircle({required this.center, required this.radiusMeters});

  final PlacesLatLng center;
  final double radiusMeters;

  @override
  Map<String, Object> toMap() => <String, Object>{
    'type': 'circle',
    'center': center.toMap(),
    'radiusMeters': radiusMeters,
  };
}

/// Rectangle from [southwest] to [northeast], e.g. a city or service area.
class PlacesRectangle extends PlacesArea {
  const PlacesRectangle({required this.southwest, required this.northeast});

  final PlacesLatLng southwest;
  final PlacesLatLng northeast;

  @override
  Map<String, Object> toMap() => <String, Object>{
    'type': 'rectangle',
    'southwest': southwest.toMap(),
    'northeast': northeast.toMap(),
  };
}
