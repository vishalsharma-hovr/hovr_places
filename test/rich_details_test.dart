import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');
  final base = <String, Object>{'placeId': 'p1', 'lat': 43.68, 'lng': -79.63};

  group('Feature: Rich place details', () {
    test('Scenario: Requested fields are sent to native', () async {
      final calls = mockNative((_) async => base);
      step(
        'When the app fetches details for "p1" with fields name and viewport',
      );
      await HovrPlaces.instance.fetchDetails(
        placeId: 'p1',
        session: session,
        fields: const {PlaceDetailsField.viewport, PlaceDetailsField.name},
      );
      step('Then native receives fields "name", "viewport"');
      expect(argsOf(calls.single)['fields'], [
        'name',
        'viewport',
      ], reason: 'stable order keeps native field lists predictable');
    });

    test('Scenario: No extra fields sends no fields list', () async {
      final calls = mockNative((_) async => base);
      step('When the app fetches details for "p1" without fields');
      await HovrPlaces.instance.fetchDetails(placeId: 'p1', session: session);
      step('Then native receives no "fields" argument');
      expect(
        argsOf(calls.single).containsKey('fields'),
        isFalse,
        reason: 'base fields only: nothing extra is billed',
      );
    });

    test(
      'Scenario: Name, address components, viewport and plus code are mapped',
      () async {
        step('Given native returns all optional fields for "p1"');
        mockNative(
          (_) async => <String, Object>{
            ...base,
            'name': 'Toronto Pearson',
            'addressComponents': [
              {
                'name': 'Mississauga',
                'shortName': 'Mississauga',
                'types': ['locality', 'political'],
              },
              {
                'name': 'L5P 1B2',
                'shortName': 'L5P 1B2',
                'types': ['postal_code'],
              },
            ],
            'viewport': {
              'southwest': {'lat': 43.66, 'lng': -79.65},
              'northeast': {'lat': 43.70, 'lng': -79.60},
            },
            'plusCode': {'globalCode': '87M2MJ6W+XX', 'compoundCode': ''},
          },
        );
        step('When the app fetches details for "p1" with every field');
        final place = await HovrPlaces.instance.fetchDetails(
          placeId: 'p1',
          session: session,
          fields: PlaceDetailsField.values.toSet(),
        );
        step('Then the app gets the name, city, viewport and plus code');
        expect(place.name, 'Toronto Pearson');
        expect(place.component('locality'), 'Mississauga', reason: 'city');
        expect(place.component('postal_code'), 'L5P 1B2', reason: 'fare zone');
        expect(place.viewport?.northeast.latitude, 43.70, reason: 'viewport');
        expect(place.plusCode?.globalCode, '87M2MJ6W+XX');
      },
    );

    test('Scenario: An airport place is flagged', () async {
      step('Given native returns place "p1" with types "airport"');
      mockNative(
        (_) async => <String, Object>{
          ...base,
          'types': ['airport'],
        },
      );
      step('When the app fetches details for "p1"');
      final place = await HovrPlaces.instance.fetchDetails(
        placeId: 'p1',
        session: session,
      );
      step('Then the place isAirport is true');
      expect(place.isAirport, isTrue);
    });
  });
}
