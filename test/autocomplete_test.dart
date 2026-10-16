import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');

  group('Feature: Autocomplete', () {
    test('Scenario: Predictions are mapped from the native result', () async {
      step('Given native returns one prediction "Union Station, Toronto"');
      mockNative(
        (_) async =>
            predictionsResult([prediction('p1', 'Union Station', 'Toronto')]),
      );
      step('When the app searches for "union station"');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'union station',
        session: session,
      );
      step(
        'Then the app gets 1 prediction with place id "p1" and primary text '
        '"Union Station"',
      );
      expect(hits, hasLength(1), reason: 'one native prediction → one hit');
      expect(hits.single.placeId, 'p1');
      expect(hits.single.primaryText, 'Union Station');
      expect(hits.single.secondaryText, 'Toronto');
    });

    test('Scenario: The query is trimmed before it is sent', () async {
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches for "  union  "');
      await HovrPlaces.instance.autocomplete(
        query: '  union  ',
        session: session,
      );
      step('Then native receives the query "union"');
      expect(
        argsOf(calls.single)['query'],
        'union',
        reason: 'surrounding spaces cost a request and change results',
      );
    });

    test('Scenario: By default no country filter is sent', () async {
      step('Given the default config');
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches for "union" without countries');
      await HovrPlaces.instance.autocomplete(query: 'union', session: session);
      step('Then native receives an empty countries list');
      expect(
        argsOf(calls.single)['countries'],
        isEmpty,
        reason: 'a shared package must not silently filter to CA/IN',
      );
    });

    test('Scenario: Default countries come from the config', () async {
      step('Given the config countries are "CA"');
      HovrPlaces.instance.configure(
        const HovrPlacesConfig(countries: <String>['CA']),
      );
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches for "union" without countries');
      await HovrPlaces.instance.autocomplete(query: 'union', session: session);
      step('Then native receives countries "CA" and no language');
      final args = argsOf(calls.single);
      expect(args['countries'], <String>['CA'], reason: 'config default');
      expect(
        args.containsKey('language'),
        isFalse,
        reason: 'null language must be omitted, not sent as null',
      );
    });

    test(
      'Scenario: Per-call countries and language override the config',
      () async {
        step('Given the config countries are "CA"');
        HovrPlaces.instance.configure(
          const HovrPlacesConfig(countries: <String>['CA']),
        );
        final calls = mockNative((_) async => predictionsResult([]));
        step(
          'When the app searches for "union" with countries "IN" and '
          'language "hi"',
        );
        await HovrPlaces.instance.autocomplete(
          query: 'union',
          session: session,
          countries: const <String>['IN'],
          language: 'hi',
        );
        step('Then native receives countries "IN" and language "hi"');
        final args = argsOf(calls.single);
        expect(args['countries'], <String>['IN'], reason: 'per-call wins');
        expect(args['language'], 'hi', reason: 'per-call wins');
      },
    );

    test(
      'Scenario: An empty query is rejected without calling native',
      () async {
        final calls = mockNative((_) async => predictionsResult([]));
        step('When the app searches for "   "');
        step('Then the search fails with "INVALID_ARGUMENT"');
        await expectLater(
          HovrPlaces.instance.autocomplete(query: '   ', session: session),
          throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        );
        step('And native receives no call');
        expect(calls, isEmpty, reason: 'blank queries must not be billed');
      },
    );

    test('Scenario: A missing predictions list means no results', () async {
      step('Given native returns a result without "predictions"');
      mockNative((_) async => <String, Object>{});
      step('When the app searches for "zzzz"');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'zzzz',
        session: session,
      );
      step('Then the app gets an empty list');
      expect(
        hits,
        isEmpty,
        reason: 'no predictions key → no results, no crash',
      );
    });

    test(
      'Scenario: A malformed prediction is reported as INVALID_ARGUMENT',
      () async {
        step('Given native returns a prediction without "primaryText"');
        mockNative(
          (_) async => predictionsResult([
            <String, Object>{'placeId': 'p1', 'fullText': 'Union'},
          ]),
        );
        step('When the app searches for "union"');
        step('Then the search fails with "INVALID_ARGUMENT"');
        await expectLater(
          HovrPlaces.instance.autocomplete(query: 'union', session: session),
          throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        );
      },
    );

    test('Scenario: Native cancellation is off unless asked for', () async {
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches for "union" without cancelPrevious');
      await HovrPlaces.instance.autocomplete(query: 'union', session: session);
      step('Then native receives no "cancelPrevious" argument');
      expect(
        argsOf(calls.single).containsKey('cancelPrevious'),
        isFalse,
        reason: '0.1.x callers (driver app) must never see CANCELLED',
      );
    });
  });
}
