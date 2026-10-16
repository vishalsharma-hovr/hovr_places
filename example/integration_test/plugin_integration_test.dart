import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';
import 'package:integration_test/integration_test.dart';

/// Live tests hit Google and are billed. Run on a real device with a key:
///   flutter test integration_test --dart-define=PLACES_LIVE=true
/// See doc/DEVICE_TESTING.md.
const live = bool.fromEnvironment('PLACES_LIVE');
const unionStation = PlacesLatLng(43.6453, -79.3806);

void step(String text) => debugPrint('    $text');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Scenario: Without a host key autocomplete fails with a typed error',
    skip: live,
    (tester) async {
      final session = HovrPlacesSession();
      try {
        await HovrPlaces.instance.autocomplete(
          query: 'union station',
          session: session,
        );
        fail('expected PlacesException when the host key is missing');
      } on PlacesException catch (error) {
        expect(
          error.code,
          anyOf(PlacesErrorCodes.missingApiKey, PlacesErrorCodes.placeError),
        );
      } finally {
        await session.close();
      }
    },
  );

  group('Live: real Google Places', skip: !live, () {
    testWidgets('Scenario: Autocomplete with origin returns sorted distances', (
      tester,
    ) async {
      final session = HovrPlacesSession();
      step(
        'When the app searches "union" around Union Station, sorted by distance',
      );
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'union',
        session: session,
        origin: unionStation,
        regionCode: 'CA',
        sortByDistance: true,
      );
      await session.close();
      step(
        'Then Google returns predictions with distanceMeters, nearest first',
      );
      expect(
        hits,
        isNotEmpty,
        reason: 'is "Places API (New)" enabled for the key?',
      );
      final distances = hits
          .map((h) => h.distanceMeters)
          .whereType<int>()
          .toList();
      expect(
        distances,
        isNotEmpty,
        reason: 'origin was sent but no distanceMeters came back',
      );
      expect(distances, orderedEquals([...distances]..sort()));
      step(
        '  first: ${hits.first.primaryText} (${hits.first.distanceMeters} m)',
      );
    });

    testWidgets('Scenario: Details with every field for an airport', (
      tester,
    ) async {
      final session = HovrPlacesSession();
      step('When the app searches airports for "pearson" and fetches details');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'pearson',
        session: session,
        types: const ['airport'],
      );
      expect(hits, isNotEmpty, reason: 'type filter returned nothing');
      final place = await HovrPlaces.instance.fetchDetails(
        placeId: hits.first.placeId,
        session: session,
        fields: PlaceDetailsField.values.toSet(),
      );
      await session.close();
      step(
        'Then the place is an airport with name, city, viewport and plus code',
      );
      expect(place.isAirport, isTrue);
      expect(place.name, isNotNull);
      expect(
        place.component('locality'),
        isNotNull,
        reason: 'addressComponents missing',
      );
      expect(place.viewport, isNotNull);
      expect(place.plusCode, isNotNull);
      expect(
        hits.first.primaryMatches,
        isNotEmpty,
        reason: 'no match ranges for bolding',
      );
    });

    testWidgets('Scenario: Nearest place to Union Station', (tester) async {
      step('When the app asks for the nearest place to Union Station');
      final nearest = await HovrPlaces.instance.nearestPlace(
        unionStation,
        radiusMeters: 200,
      );
      step(
        'Then a place with an address comes back: ${nearest?.formattedAddress}',
      );
      expect(nearest, isNotNull);
      expect(nearest!.formattedAddress, isNotEmpty);
    });
  });
}
