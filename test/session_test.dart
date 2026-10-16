import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  usePlacesChannel();

  group('Feature: Places session lifecycle', () {
    test('Scenario: A new session gets a UUID v4 token', () {
      step('Given a new Places session');
      final session = HovrPlacesSession();
      step('Then its token is a 36-character UUID v4');
      expect(
        session.token,
        matches(_uuidV4),
        reason: 'Google session tokens must be UUID v4, got "${session.token}"',
      );
    });

    test('Scenario: Two sessions never share a token', () {
      step('Given two new Places sessions');
      final a = HovrPlacesSession();
      final b = HovrPlacesSession();
      step('Then their tokens are different');
      expect(
        a.token,
        isNot(b.token),
        reason: 'two sessions sharing a token would merge their billing',
      );
    });

    test('Scenario: Closing a session tells native to drop it', () async {
      step('Given an open session "sess-1"');
      final calls = mockNative((_) async => null);
      final session = HovrPlacesSession(token: 'sess-1');
      step('When the session is closed');
      await session.close();
      step('Then native receives "endSession" with token "sess-1"');
      expect(methodsOf(calls), <String>[PlacesChannels.endSession]);
      expect(
        argsOf(calls.single)['sessionToken'],
        'sess-1',
        reason: 'native must drop the SDK token mapped to this session',
      );
      step('And the session is marked closed');
      expect(session.isClosed, isTrue, reason: 'session.isClosed after close');
    });

    test('Scenario: Closing a session twice only calls native once', () async {
      step('Given an open session "sess-1"');
      final calls = mockNative((_) async => null);
      final session = HovrPlacesSession(token: 'sess-1');
      step('When the session is closed twice');
      await session.close();
      await session.close();
      step('Then native receives "endSession" exactly once');
      expect(methodsOf(calls), <String>[
        PlacesChannels.endSession,
      ], reason: 'second close() must be a no-op');
    });

    test(
      'Scenario: A closed session cannot be used for autocomplete',
      () async {
        step('Given a closed session "sess-1"');
        final calls = mockNative((_) async => null);
        final session = HovrPlacesSession(token: 'sess-1');
        await session.close();
        step('When the app searches for "union"');
        step('Then the search fails with "INVALID_ARGUMENT"');
        await expectLater(
          HovrPlaces.instance.autocomplete(query: 'union', session: session),
          throwsPlacesCode(PlacesErrorCodes.invalidArgument),
        );
        step('And native receives no autocomplete call');
        expect(
          methodsOf(calls),
          isNot(contains(PlacesChannels.autocomplete)),
          reason: 'a closed session must be rejected in Dart, before native',
        );
      },
    );

    test(
      'Scenario: Autocomplete and details share the same session token',
      () async {
        step('Given an open session "sess-1"');
        final calls = mockNative((MethodCall call) async {
          if (call.method == PlacesChannels.autocomplete) {
            return predictionsResult([prediction('p1', 'Union', 'Toronto')]);
          }
          return <String, Object>{'placeId': 'p1', 'lat': 1.0, 'lng': 2.0};
        });
        final session = HovrPlacesSession(token: 'sess-1');
        step('When the app searches for "union" and fetches details for "p1"');
        await HovrPlaces.instance.autocomplete(
          query: 'union',
          session: session,
        );
        await HovrPlaces.instance.fetchDetails(placeId: 'p1', session: session);
        step('Then both native calls carry token "sess-1"');
        for (final call in calls) {
          expect(
            argsOf(call)['sessionToken'],
            'sess-1',
            reason: '${call.method} must use the session token for billing',
          );
        }
      },
    );
  });
}
