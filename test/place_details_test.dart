import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');

  Future<PlaceDetails> fetchP1() =>
      HovrPlaces.instance.fetchDetails(placeId: 'p1', session: session);

  group('Feature: Place details', () {
    test(
      'Scenario: Coordinates and address are mapped from the native result',
      () async {
        step('Given native returns place "p1" at 43.65, -79.38 in "Toronto"');
        mockNative(
          (_) async => <String, Object>{
            'placeId': 'p1',
            'lat': 43.65,
            'lng': -79.38,
            'formattedAddress': 'Toronto',
            'types': <String>['transit_station'],
          },
        );
        step('When the app fetches details for "p1"');
        final place = await fetchP1();
        step(
          'Then the app gets latitude 43.65, longitude -79.38 and address '
          '"Toronto"',
        );
        expect(place.latitude, 43.65, reason: 'pickup latitude');
        expect(place.longitude, -79.38, reason: 'pickup longitude');
        expect(place.formattedAddress, 'Toronto');
        expect(place.types, <String>['transit_station']);
      },
    );

    test('Scenario: String coordinates are accepted', () async {
      step('Given native returns latitude as the string "43.65"');
      mockNative(
        (_) async => <String, Object>{
          'placeId': 'p1',
          'lat': '43.65',
          'lng': -79.38,
        },
      );
      step('When the app fetches details for "p1"');
      final place = await fetchP1();
      step('Then the app gets latitude 43.65');
      expect(place.latitude, 43.65, reason: '"43.65" must parse to a double');
    });

    test('Scenario: A place without coordinates is rejected', () async {
      step('Given native returns place "p1" without "lat"');
      mockNative((_) async => <String, Object>{'placeId': 'p1', 'lng': -79.38});
      step('When the app fetches details for "p1"');
      step('Then the fetch fails with "INVALID_ARGUMENT"');
      await expectLater(
        fetchP1(),
        throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        reason: 'a place with no coordinates must never become a pickup',
      );
    });

    test('Scenario: Out-of-range coordinates are rejected', () async {
      step('Given native returns place "p1" at -180, -180');
      mockNative(
        (_) async => <String, Object>{
          'placeId': 'p1',
          'lat': -180,
          'lng': -180,
        },
      );
      step('When the app fetches details for "p1"');
      step('Then the fetch fails with "INVALID_ARGUMENT"');
      await expectLater(
        fetchP1(),
        throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        reason: "-180, -180 is iOS's invalid-coordinate value, not a place",
      );
    });

    test(
      'Scenario: An empty place id is rejected without calling native',
      () async {
        final calls = mockNative((_) async => null);
        step('When the app fetches details for "  "');
        step('Then the fetch fails with "INVALID_ARGUMENT"');
        await expectLater(
          HovrPlaces.instance.fetchDetails(placeId: '  ', session: session),
          throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        );
        step('And native receives no call');
        expect(calls, isEmpty, reason: 'blank place ids must not be billed');
      },
    );
  });
}
