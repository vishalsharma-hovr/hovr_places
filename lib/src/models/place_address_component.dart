import '../channels/places_payload.dart';

/// One part of an address, e.g. name "Toronto" with types `[locality]`.
class PlaceAddressComponent {
  const PlaceAddressComponent({
    required this.name,
    this.shortName = '',
    this.types = const <String>[],
  });

  factory PlaceAddressComponent.fromMap(Map<String, Object?> map) {
    return PlaceAddressComponent(
      name: requiredString(map['name'], 'addressComponents.name'),
      shortName: optionalString(map['shortName']),
      types: stringList(map['types'], 'addressComponents.types'),
    );
  }

  final String name;
  final String shortName;
  final List<String> types;
}

/// Plus code, e.g. global "87M2MJ6W+XX", compound "MJ6W+XX Toronto".
class PlacePlusCode {
  const PlacePlusCode({required this.globalCode, this.compoundCode = ''});

  factory PlacePlusCode.fromMap(Map<String, Object?> map) {
    return PlacePlusCode(
      globalCode: requiredString(map['globalCode'], 'plusCode.globalCode'),
      compoundCode: optionalString(map['compoundCode']),
    );
  }

  final String globalCode;
  final String compoundCode;
}
