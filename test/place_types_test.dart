import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');

  group('Feature: Place types and region', () {
    test('Scenario: Type filters are sent to native', () async {
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches for "pearson" with types "airport"');
      await HovrPlaces.instance.autocomplete(
        query: 'pearson',
        session: session,
        types: const ['airport'],
      );
      step('Then native receives types "airport"');
      expect(argsOf(calls.single)['types'], ['airport']);
    });

    test('Scenario: More than 5 type filters are rejected', () async {
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches with 6 type filters');
      step('Then the search fails with "INVALID_ARGUMENT"');
      await expectLater(
        HovrPlaces.instance.autocomplete(
          query: 'union',
          session: session,
          types: List.filled(6, 'airport'),
        ),
        throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        reason: 'Google allows at most 5 autocomplete types',
      );
      step('And native receives no call');
      expect(calls, isEmpty);
    });

    test(
      'Scenario: Region code from the config is sent with autocomplete',
      () async {
        step('Given the config region code is "IN"');
        HovrPlaces.instance.configure(const HovrPlacesConfig(regionCode: 'IN'));
        final calls = mockNative((_) async => predictionsResult([]));
        step('When the app searches for "connaught"');
        await HovrPlaces.instance.autocomplete(
          query: 'connaught',
          session: session,
        );
        step('Then native receives regionCode "IN"');
        expect(argsOf(calls.single)['regionCode'], 'IN');
      },
    );

    test('Scenario: A bad region code is rejected', () async {
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches with region code "IND"');
      step('Then the search fails with "INVALID_ARGUMENT"');
      await expectLater(
        HovrPlaces.instance.autocomplete(
          query: 'union',
          session: session,
          regionCode: 'IND',
        ),
        throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        reason: 'region codes are 2-letter CLDR codes',
      );
      step('And native receives no call');
      expect(calls, isEmpty);
    });

    test('Scenario: An airport prediction is flagged', () async {
      step('Given native returns "Toronto Pearson" with types "airport"');
      mockNative(
        (_) async => predictionsResult([
          <String, Object>{
            ...prediction('yyz', 'Toronto Pearson', 'Mississauga'),
            'types': ['airport', 'point_of_interest'],
          },
        ]),
      );
      step('When the app searches for "pearson"');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'pearson',
        session: session,
      );
      step('Then the prediction isAirport is true');
      expect(hits.single.isAirport, isTrue, reason: 'terminal picker trigger');
    });
  });
}
