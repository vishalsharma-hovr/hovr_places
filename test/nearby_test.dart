import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  const here = PlacesLatLng(43.65, -79.38);

  Map<String, Object> place(String id) => <String, Object>{
    'placeId': id,
    'lat': 43.65,
    'lng': -79.38,
    'formattedAddress': '$id St, Toronto',
  };

  group('Feature: Nearby search and current location', () {
    test(
      'Scenario: Nearby search sends center, radius, types and ranking',
      () async {
        final calls = mockNative((_) async => <String, Object>{'places': []});
        step(
          'When the app searches 500 m around 43.65, -79.38 for '
          '"electric_vehicle_charging_station" ranked by distance',
        );
        await HovrPlaces.instance.searchNearby(
          area: const PlacesCircle(center: here, radiusMeters: 500),
          types: const ['electric_vehicle_charging_station'],
          rankByDistance: true,
        );
        step(
          'Then native receives that center, radius, types and rankBy '
          '"distance"',
        );
        final args = argsOf(calls.single);
        expect(calls.single.method, PlacesChannels.searchNearby);
        expect(args['center'], {'lat': 43.65, 'lng': -79.38});
        expect(args['radiusMeters'], 500.0);
        expect(args['types'], ['electric_vehicle_charging_station']);
        expect(args['rankBy'], 'distance');
        expect(
          args.containsKey('sessionToken'),
          isFalse,
          reason: 'nearby search is not part of an autocomplete session',
        );
      },
    );

    test('Scenario: Nearby places are mapped', () async {
      step('Given native returns 2 nearby places');
      mockNative(
        (_) async => <String, Object>{
          'places': [place('a'), place('b')],
        },
      );
      step('When the app searches nearby');
      final places = await HovrPlaces.instance.searchNearby(
        area: const PlacesCircle(center: here, radiusMeters: 500),
      );
      step('Then the app gets 2 places with coordinates');
      expect(places.map((p) => p.placeId), ['a', 'b']);
      expect(places.first.latitude, 43.65);
    });

    test('Scenario: maxResults above 20 is rejected', () async {
      final calls = mockNative((_) async => <String, Object>{'places': []});
      step('When the app searches nearby with maxResults 21');
      step('Then the search fails with "INVALID_ARGUMENT"');
      await expectLater(
        HovrPlaces.instance.searchNearby(
          area: const PlacesCircle(center: here, radiusMeters: 500),
          maxResults: 21,
        ),
        throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        reason: 'Google returns at most 20 nearby places',
      );
      step('And native receives no call');
      expect(calls, isEmpty);
    });

    test(
      'Scenario: Nearest place asks for one result ranked by distance',
      () async {
        final calls = mockNative(
          (_) async => <String, Object>{
            'places': [place('closest')],
          },
        );
        step('When the app asks for the nearest place to 43.65, -79.38');
        final nearest = await HovrPlaces.instance.nearestPlace(here);
        step(
          'Then native receives maxResults 1, rankBy "distance" and radius '
          '100 m',
        );
        final args = argsOf(calls.single);
        expect(args['maxResults'], 1);
        expect(args['rankBy'], 'distance', reason: 'closest, not most popular');
        expect(args['radiusMeters'], 100.0);
        expect(nearest?.placeId, 'closest');
      },
    );

    test('Scenario: Nearest place is null when nothing is nearby', () async {
      step('Given native returns no nearby places');
      mockNative((_) async => <String, Object>{'places': []});
      step('When the app asks for the nearest place');
      final nearest = await HovrPlaces.instance.nearestPlace(here);
      step('Then the app gets null');
      expect(nearest, isNull, reason: 'the app falls back to raw coordinates');
    });
  });
}
