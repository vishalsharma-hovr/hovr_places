import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');

  group('Feature: Error mapping', () {
    for (final code in <String>[
      PlacesErrorCodes.missingApiKey,
      PlacesErrorCodes.placeError,
      PlacesErrorCodes.invalidArgument,
      PlacesErrorCodes.cancelled,
    ]) {
      test(
        'Scenario Outline: Native error codes reach the app unchanged [$code]',
        () async {
          step('Given native fails with "$code"');
          mockNative(
            (_) async => throw PlatformException(code: code, message: 'boom'),
          );
          step('When the app searches for "union"');
          step('Then the search fails with "$code"');
          await expectLater(
            HovrPlaces.instance.autocomplete(query: 'union', session: session),
            throwsPlacesCode(code),
            reason: 'the app branches on this code to show the right message',
          );
        },
      );
    }

    test('Scenario: Plugin not registered maps to UNIMPLEMENTED', () async {
      step('Given no native plugin is registered');
      step('When the app searches for "union"');
      step('Then the search fails with "UNIMPLEMENTED"');
      await expectLater(
        HovrPlaces.instance.autocomplete(query: 'union', session: session),
        throwsPlacesCode(PlacesErrorCodes.unimplemented),
        reason: 'MissingPluginException must not leak to the app',
      );
    });

    test(
      'Scenario: An unknown error maps to PLACE_ERROR without leaking details',
      () {
        step('Given a non-platform error "secret AIza123"');
        step('When it is converted to a PlacesException');
        final error = PlacesException.fromPlatform(
          StateError('secret AIza123'),
        );
        step(
          'Then the code is "PLACE_ERROR" and the message does not contain '
          '"AIza"',
        );
        expect(error.code, PlacesErrorCodes.placeError);
        expect(
          error.message,
          isNot(contains('AIza')),
          reason: 'raw error text may contain the API key and must be hidden',
        );
      },
    );

    test('Scenario: The native error code is exposed for support', () async {
      step('Given native fails with "PLACE_ERROR" and native code 9011');
      mockNative(
        (_) async => throw PlatformException(
          code: PlacesErrorCodes.placeError,
          message: 'API key rejected',
          details: <String, Object>{'nativeCode': 9011},
        ),
      );
      step('When the app searches for "union"');
      final error = await HovrPlaces.instance
          .autocomplete(query: 'union', session: session)
          .then<PlacesException?>(
            (_) => null,
            onError: (Object e) => e as PlacesException,
          );
      step("Then the exception's nativeCode is 9011");
      expect(
        error?.nativeCode,
        9011,
        reason:
            'apps need this to tell a key misconfiguration from a network error',
      );
    });
  });
}
