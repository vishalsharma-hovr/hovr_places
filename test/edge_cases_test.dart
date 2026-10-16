import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

const _codes = [
  'CA', 'IN', 'US', 'GB', 'FR', 'DE', 'IT', 'ES', //
  'MX', 'BR', 'AU', 'NZ', 'JP', 'AE', 'SG', 'ZA',
];

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');

  Future<List<PlacePrediction>> search({
    String query = 'union',
    List<String>? countries,
    PlacesLatLng? origin,
    PlacesArea? restriction,
    HovrPlacesSession? inSession,
  }) => HovrPlaces.instance.autocomplete(
    query: query,
    session: inSession ?? session,
    countries: countries,
    origin: origin,
    locationRestriction: restriction,
  );

  List<MethodCall> emptyNative() =>
      mockNative((_) async => predictionsResult([]));

  group("Feature: Edge cases from Google's documented limits", () {
    test('Scenario: More than 15 countries are rejected', () async {
      final calls = emptyNative();
      step('When the app searches with 16 countries');
      step('Then the search fails with "INVALID_ARGUMENT"');
      await expectLater(
        search(countries: _codes),
        throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        reason:
            'Google caps includedRegionCodes at 15; 16 would be an opaque 9012',
      );
      step('And native receives no call');
      expect(calls, isEmpty);
    });

    test(
      'Scenario: A country code that is not 2 letters is rejected',
      () async {
        emptyNative();
        step('When the app searches with countries "CAN"');
        step('Then the search fails with "INVALID_ARGUMENT"');
        await expectLater(
          search(countries: ['CAN']),
          throwsPlacesCode(PlacesErrorCodes.invalidArgument),
          reason: 'ISO alpha-3 codes are a common mistake',
        );
      },
    );

    test('Scenario: Exactly 15 countries are accepted', () async {
      final calls = emptyNative();
      step('When the app searches with 15 countries');
      await search(countries: _codes.take(15).toList());
      step('Then native receives 15 countries');
      expect(argsOf(calls.single)['countries'], hasLength(15));
    });

    test(
      'Scenario: A rectangle crossing the 180° meridian is accepted',
      () async {
        final calls = emptyNative();
        step('When the app restricts to a rectangle from lng 170 to lng -170');
        await search(
          restriction: const PlacesRectangle(
            southwest: PlacesLatLng(-20, 170),
            northeast: PlacesLatLng(-10, -170),
          ),
        );
        step('Then native receives that rectangle unchanged');
        expect(
          argsOf(calls.single)['locationRestriction'],
          containsPair('southwest', {'lat': -20.0, 'lng': 170.0}),
          reason:
              'sw.lng > ne.lng is how Google expresses a date-line crossing',
        );
      },
    );

    test(
      'Scenario: A 50 km circle is accepted and 50.0001 km is rejected',
      () async {
        final calls = emptyNative();
        const center = PlacesLatLng(43.65, -79.38);
        step(
          'When the app restricts to a 50000 m circle, then a 50000.1 m circle',
        );
        await search(
          restriction: const PlacesCircle(center: center, radiusMeters: 50000),
        );
        step(
          'Then the first is sent and the second fails with "INVALID_ARGUMENT"',
        );
        expect(
          calls,
          hasLength(1),
          reason: '50000.0 is inclusive in Google docs',
        );
        await expectLater(
          search(
            restriction: const PlacesCircle(
              center: center,
              radiusMeters: 50000.1,
            ),
          ),
          throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        );
      },
    );

    test('Scenario: Poles and the date line are valid coordinates', () async {
      final calls = emptyNative();
      step('When the app sends origins at lat 90, lat -90 and lng 180');
      for (final origin in const [
        PlacesLatLng(90, 0),
        PlacesLatLng(-90, 0),
        PlacesLatLng(0, 180),
      ]) {
        await search(origin: origin);
      }
      step('Then all three reach native');
      expect(calls, hasLength(3), reason: 'range bounds are inclusive');
      step('And lat 90.0001 fails with "INVALID_ARGUMENT"');
      await expectLater(
        search(origin: const PlacesLatLng(90.0001, 0)),
        throwsPlacesCode(PlacesErrorCodes.invalidArgument),
      );
    });

    for (final query in const [
      'दिल्ली रेलवे स्टेशन',
      'Montréal–Trudeau',
      'مطار دبي',
      '🚉 Union',
      "O'Hare & 5th Ave.",
    ]) {
      test(
        'Scenario Outline: Non-English and unusual queries reach native unchanged [$query]',
        () async {
          final calls = emptyNative();
          step('When the app searches for "$query"');
          await search(query: query);
          step('Then native receives exactly "$query"');
          expect(
            argsOf(calls.single)['query'],
            query,
            reason: 'riders in IN/CA type Hindi, French and symbols',
          );
        },
      );
    }

    test('Scenario: A 1000-character query is sent without crashing', () async {
      final calls = emptyNative();
      final long = 'a' * 1000;
      step('When the app searches for a 1000-character query');
      await search(query: long);
      step('Then native receives all 1000 characters');
      expect((argsOf(calls.single)['query']! as String).length, 1000);
    });

    for (final (code, meaning) in const [
      (9010, 'OVER_QUERY_LIMIT'),
      (9011, 'REQUEST_DENIED'),
      (9012, 'INVALID_REQUEST'),
      (9013, 'NOT_FOUND'),
      (15, 'TIMEOUT'),
      (7, 'NETWORK_ERROR'),
    ]) {
      test(
        "Scenario Outline: Google's native status codes reach the app [$code $meaning]",
        () async {
          step('Given native fails with "PLACE_ERROR" and native code $code');
          mockNative(
            (_) async => throw PlatformException(
              code: PlacesErrorCodes.placeError,
              message: meaning,
              details: <String, Object>{'nativeCode': code},
            ),
          );
          step('When the app searches for "union"');
          PlacesException? error;
          try {
            await search();
          } on PlacesException catch (e) {
            error = e;
          }
          step("Then the exception's nativeCode is $code");
          expect(error?.code, PlacesErrorCodes.placeError);
          expect(
            error?.nativeCode,
            code,
            reason: '$meaning must be distinguishable',
          );
        },
      );
    }

    test(
      'Scenario: A place that no longer exists fails details with NOT_FOUND',
      () async {
        step(
          'Given native fails details with "PLACE_ERROR" and native code 9013',
        );
        mockNative(
          (_) async => throw PlatformException(
            code: PlacesErrorCodes.placeError,
            details: <String, Object>{'nativeCode': 9013},
          ),
        );
        step('When the app fetches details for "stale-id"');
        PlacesException? error;
        try {
          await HovrPlaces.instance.fetchDetails(
            placeId: 'stale-id',
            session: session,
          );
        } on PlacesException catch (e) {
          error = e;
        }
        step('Then the fetch fails with "PLACE_ERROR" and nativeCode 9013');
        expect(error?.code, PlacesErrorCodes.placeError);
        expect(
          error?.nativeCode,
          9013,
          reason:
              'saved place IDs can expire; the app must re-search, not crash',
        );
      },
    );

    test('Scenario: Concurrent searches each get their own answer', () async {
      step('Given native echoes each query back as the prediction');
      mockNative((MethodCall call) async {
        final query = argsOf(call)['query']! as String;
        await Future<void>.delayed(Duration(milliseconds: query.length % 7));
        return predictionsResult([prediction(query, query, 'echo')]);
      });
      step('When the app runs 20 searches at once');
      final queries = [for (var i = 0; i < 20; i++) 'query $i'];
      final results = await Future.wait([
        for (final q in queries) search(query: q),
      ]);
      step('Then every search gets the prediction for its own query');
      for (var i = 0; i < queries.length; i++) {
        expect(
          results[i].single.placeId,
          queries[i],
          reason:
              'replies must not cross between callers (rider event-channel bug)',
        );
      }
    });

    test('Scenario: Two sessions keep separate tokens', () async {
      final calls = emptyNative();
      step(
        'When the app searches in session "rider-pickup" and "rider-dropoff" at once',
      );
      await Future.wait([
        search(inSession: HovrPlacesSession(token: 'rider-pickup')),
        search(inSession: HovrPlacesSession(token: 'rider-dropoff')),
      ]);
      step('Then each native call carries its own session token');
      expect(calls.map((c) => argsOf(c)['sessionToken']).toSet(), {
        'rider-pickup',
        'rider-dropoff',
      }, reason: 'pickup and drop-off must be billed as separate sessions');
    });

    testWidgets('Scenario: Highlighting survives emoji before the match', (
      tester,
    ) async {
      step('Given native returns "🚉 Union" with match 3, 5');
      mockNative(
        (_) async => predictionsResult([
          <String, Object>{
            ...prediction('p1', '🚉 Union', 'Toronto'),
            'primaryMatches': [
              [3, 5],
            ],
          },
        ]),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HovrPlacesAutocompleteField())),
      );
      step('When the rider types "union" and waits 300 ms');
      await tester.enterText(find.byType(TextField), 'union');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      step('Then "Union" is bold');
      final title = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == '🚉 Union',
        ),
      );
      final parts = (title.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(parts.map((p) => p.text), [
        '🚉 ',
        'Union',
      ], reason: 'offsets are UTF-16; the emoji is 2 code units');
      expect(parts.last.style?.fontWeight, FontWeight.bold);
    });

    for (final (meters, label) in const [
      (0, '0 m'),
      (999, '999 m'),
      (1000, '1.0 km'),
      (9999, '10.0 km'),
    ]) {
      test(
        'Scenario Outline: Distance labels at the unit boundary [$meters m]',
        () {
          step('Then $meters m is labelled "$label"');
          expect(formatDistanceMeters(meters), label);
        },
      );
    }
  });
}
