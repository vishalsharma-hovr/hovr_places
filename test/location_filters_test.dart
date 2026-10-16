import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');
  const toronto = PlacesCircle(
    center: PlacesLatLng(43.65, -79.38),
    radiusMeters: 5000,
  );
  const gta = PlacesRectangle(
    southwest: PlacesLatLng(43.58, -79.64),
    northeast: PlacesLatLng(43.86, -79.12),
  );

  /// Expects INVALID_ARGUMENT and that native was never called.
  Future<void> expectRejected({
    PlacesArea? bias,
    PlacesArea? restriction,
    required String why,
  }) async {
    final calls = mockNative((_) async => predictionsResult([]));
    step('Then the search fails with "INVALID_ARGUMENT"');
    await expectLater(
      HovrPlaces.instance.autocomplete(
        query: 'union',
        session: session,
        locationBias: bias,
        locationRestriction: restriction,
      ),
      throwsPlacesCode(PlacesErrorCodes.invalidArgument),
      reason: why,
    );
    step('And native receives no call');
    expect(calls, isEmpty, reason: 'bad input must not be billed');
  }

  group('Feature: Location bias and restriction', () {
    test('Scenario: A circular bias is sent to native', () async {
      step('Given a circle of 5000 m around 43.65, -79.38');
      final calls = mockNative((_) async => predictionsResult([]));
      step(
        'When the app searches for "union" with that circle as locationBias',
      );
      await HovrPlaces.instance.autocomplete(
        query: 'union',
        session: session,
        locationBias: toronto,
      );
      step(
        'Then native receives locationBias type "circle" with that center '
        'and radius',
      );
      expect(argsOf(calls.single)['locationBias'], <String, Object>{
        'type': 'circle',
        'center': <String, Object>{'lat': 43.65, 'lng': -79.38},
        'radiusMeters': 5000.0,
      }, reason: 'native parsers expect exactly this shape');
    });

    test('Scenario: A rectangular restriction is sent to native', () async {
      step('Given a rectangle from 43.58, -79.64 to 43.86, -79.12');
      final calls = mockNative((_) async => predictionsResult([]));
      step(
        'When the app searches for "union" with that rectangle as '
        'locationRestriction',
      );
      await HovrPlaces.instance.autocomplete(
        query: 'union',
        session: session,
        locationRestriction: gta,
      );
      step(
        'Then native receives locationRestriction type "rectangle" with those '
        'corners',
      );
      expect(argsOf(calls.single)['locationRestriction'], <String, Object>{
        'type': 'rectangle',
        'southwest': <String, Object>{'lat': 43.58, 'lng': -79.64},
        'northeast': <String, Object>{'lat': 43.86, 'lng': -79.12},
      }, reason: 'native parsers expect exactly this shape');
    });

    test('Scenario: Bias and restriction together are rejected', () async {
      step(
        'When the app searches with both locationBias and locationRestriction',
      );
      await expectRejected(
        bias: toronto,
        restriction: gta,
        why: 'Google rejects requests that set both',
      );
    });

    test('Scenario: A radius over 50 km is rejected', () async {
      step('When the app searches with a 60000 m circle as locationBias');
      await expectRejected(
        bias: const PlacesCircle(
          center: PlacesLatLng(43.65, -79.38),
          radiusMeters: 60000,
        ),
        why: 'Google caps the radius at 50 000 m',
      );
    });

    test(
      'Scenario: A rectangle with southwest north of northeast is rejected',
      () async {
        step(
          'When the app searches with a rectangle whose southwest is north of '
          'its northeast',
        );
        await expectRejected(
          restriction: const PlacesRectangle(
            southwest: PlacesLatLng(43.86, -79.64),
            northeast: PlacesLatLng(43.58, -79.12),
          ),
          why: 'swapped corners would silently search the wrong area',
        );
      },
    );
  });
}
