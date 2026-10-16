import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');
  const rider = PlacesLatLng(43.6453, -79.3806);

  /// Native answers with one prediction per entry: (id, distance or null).
  List<MethodCall> nativeReturns(List<(String, int?)> hits) => mockNative(
    (_) async => predictionsResult([
      for (final (id, meters) in hits)
        prediction(id, id, 'Toronto', distanceMeters: meters),
    ]),
  );

  Future<List<String>> searchIds({bool sort = true}) async {
    final hits = await HovrPlaces.instance.autocomplete(
      query: 'union',
      session: session,
      origin: rider,
      sortByDistance: sort,
    );
    return [for (final hit in hits) hit.placeId];
  }

  group('Feature: Sort predictions by distance', () {
    test('Scenario: The origin is sent to native', () async {
      step('Given the rider is at 43.6453, -79.3806');
      final calls = mockNative((_) async => predictionsResult([]));
      step('When the app searches for "union" with that origin');
      await HovrPlaces.instance.autocomplete(
        query: 'union',
        session: session,
        origin: rider,
      );
      step('Then native receives origin lat 43.6453 and lng -79.3806');
      expect(argsOf(calls.single)['origin'], <String, Object>{
        'lat': 43.6453,
        'lng': -79.3806,
      }, reason: 'Google only returns distanceMeters when an origin is sent');
    });

    test('Scenario: Distance is mapped onto each prediction', () async {
      step('Given native returns "Union Station" with distanceMeters 1200');
      mockNative(
        (_) async => predictionsResult([
          prediction('p1', 'Union Station', 'Toronto', distanceMeters: 1200),
        ]),
      );
      step('When the app searches for "union" with an origin');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'union',
        session: session,
        origin: rider,
      );
      step('Then the prediction has distanceMeters 1200');
      expect(hits.single.distanceMeters, 1200, reason: 'distance was dropped');
    });

    test('Scenario: Predictions are sorted nearest first', () async {
      step('Given native returns predictions at 5000 m, 300 m and 1200 m');
      nativeReturns([('far', 5000), ('near', 300), ('mid', 1200)]);
      step('When the app searches with sortByDistance enabled');
      final ids = await searchIds();
      step('Then the predictions come back as 300 m, 1200 m, 5000 m');
      expect(ids, ['near', 'mid', 'far'], reason: 'not sorted nearest first');
    });

    test('Scenario: Predictions without a distance go last', () async {
      step('Given native returns predictions at 800 m, no distance, and 200 m');
      nativeReturns([('mid', 800), ('unknown', null), ('near', 200)]);
      step('When the app searches with sortByDistance enabled');
      final ids = await searchIds();
      step('Then the predictions come back as 200 m, 800 m, no distance');
      expect(ids, [
        'near',
        'mid',
        'unknown',
      ], reason: 'a place with unknown distance must not look nearest');
    });

    test("Scenario: Equal distances keep Google's order", () async {
      step('Given native returns A, B and C all at 500 m');
      nativeReturns([('A', 500), ('B', 500), ('C', 500)]);
      step('When the app searches with sortByDistance enabled');
      final ids = await searchIds();
      step('Then the predictions come back as A, B, C');
      expect(ids, [
        'A',
        'B',
        'C',
      ], reason: 'sort must be stable so Google relevance breaks ties');
    });

    test("Scenario: Without sortByDistance Google's order is kept", () async {
      step('Given native returns predictions at 5000 m, 300 m and 1200 m');
      nativeReturns([('far', 5000), ('near', 300), ('mid', 1200)]);
      step('When the app searches without sortByDistance');
      final ids = await searchIds(sort: false);
      step('Then the predictions come back as 5000 m, 300 m, 1200 m');
      expect(ids, ['far', 'near', 'mid'], reason: 'sorting must be opt-in');
    });

    test(
      'Scenario: An out-of-range origin is rejected without calling native',
      () async {
        final calls = mockNative((_) async => predictionsResult([]));
        step('When the app searches with origin 95, 0');
        step('Then the search fails with "INVALID_ARGUMENT"');
        await expectLater(
          HovrPlaces.instance.autocomplete(
            query: 'union',
            session: session,
            origin: const PlacesLatLng(95, 0),
          ),
          throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        );
        step('And native receives no call');
        expect(calls, isEmpty, reason: 'bad input must not be billed');
      },
    );
  });
}
