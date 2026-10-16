import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  List<PlacesUsageEvent> listen() {
    final events = <PlacesUsageEvent>[];
    HovrPlaces.instance.onUsage = events.add;
    return events;
  }

  group('Feature: Usage events', () {
    test('Scenario: A successful call reports a usage event', () async {
      step('Given the app listens to onUsage');
      final events = listen();
      mockNative((_) async => predictionsResult([]));
      step('When the app searches for "union" in session "sess-1"');
      await HovrPlaces.instance.autocomplete(
        query: 'union',
        session: HovrPlacesSession(token: 'sess-1'),
      );
      step(
        'Then one event is reported for "autocomplete" in "sess-1" with no error',
      );
      expect(events, hasLength(1), reason: 'one billed call → one event');
      expect(events.single.method, PlacesChannels.autocomplete);
      expect(events.single.sessionToken, 'sess-1');
      expect(events.single.succeeded, isTrue);
    });

    test('Scenario: A failed call reports its error code', () async {
      step('Given the app listens to onUsage');
      final events = listen();
      step('And native fails with "PLACE_ERROR"');
      mockNative(
        (_) async => throw PlatformException(code: PlacesErrorCodes.placeError),
      );
      step('When the app searches for "union"');
      await expectLater(
        HovrPlaces.instance.autocomplete(
          query: 'union',
          session: HovrPlacesSession(),
        ),
        throwsPlacesCode(PlacesErrorCodes.placeError),
      );
      step('Then the event has error code "PLACE_ERROR"');
      expect(
        events.single.errorCode,
        PlacesErrorCodes.placeError,
        reason: 'failed calls may still be billed and must be counted',
      );
    });

    test('Scenario: Nearby calls report no session token', () async {
      step('Given the app listens to onUsage');
      final events = listen();
      mockNative((_) async => <String, Object>{'places': []});
      step('When the app searches nearby');
      await HovrPlaces.instance.searchNearby(
        area: const PlacesCircle(
          center: PlacesLatLng(43.65, -79.38),
          radiusMeters: 500,
        ),
      );
      step('Then the event for "searchNearby" has no session token');
      expect(events.single.method, PlacesChannels.searchNearby);
      expect(events.single.sessionToken, isNull);
    });
  });
}
