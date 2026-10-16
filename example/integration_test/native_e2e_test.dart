import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end through the real Kotlin / Swift plugin, no Google key needed.
/// The raw channel skips Dart validation on purpose, so the native parsers
/// are the ones under test. Run: `flutter test integration_test -d <device>`
const raw = MethodChannel(PlacesChannels.name);
const live = bool.fromEnvironment('PLACES_LIVE');

void step(String text) => debugPrint('    $text');

/// The error code native answers with, or 'OK' when it succeeds.
Future<String> nativeCode(String method, Object? args) async {
  try {
    await raw
        .invokeMethod<Object?>(method, args)
        .timeout(const Duration(seconds: 10));
    return 'OK';
  } on PlatformException catch (error) {
    expect(
      '${error.message}${error.details}',
      isNot(contains('AIza')),
      reason: 'native error text must never contain an API key',
    );
    return error.code;
  } on MissingPluginException {
    return PlacesErrorCodes.unimplemented;
  }
}

const ok = {'query': 'union station', 'sessionToken': 'e2e-session'};
const center = {'lat': 43.65, 'lng': -79.38};
const circle = {'type': 'circle', 'center': center, 'radiusMeters': 5000.0};
const nearby = {'center': center, 'radiusMeters': 500.0};
const codes = [
  'CA',
  'IN',
  'US',
  'GB',
  'FR',
  'DE',
  'IT',
  'ES',
  'MX',
  'BR',
  'AU',
  'NZ',
  'JP',
  'AE',
  'SG',
  'ZA',
];

Map<String, Object?> withArgs(
  Map<String, Object?> base,
  Map<String, Object?> extra,
) => {...base, ...extra};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Feature: Native argument validation (real ${defaultTargetPlatform.name} parsers)',
    () {
      final cases = <(String, String, Object?)>[
        (
          'autocomplete args that are not a map',
          PlacesChannels.autocomplete,
          'union station',
        ),
        (
          'autocomplete without query',
          PlacesChannels.autocomplete,
          {'sessionToken': 's'},
        ),
        (
          'autocomplete without sessionToken',
          PlacesChannels.autocomplete,
          {'query': 'union'},
        ),
        (
          'origin latitude 95',
          PlacesChannels.autocomplete,
          withArgs(ok, {
            'origin': {'lat': 95.0, 'lng': 0.0},
          }),
        ),
        (
          'origin NaN',
          PlacesChannels.autocomplete,
          withArgs(ok, {
            'origin': {'lat': double.nan, 'lng': 0.0},
          }),
        ),
        (
          'bias and restriction together',
          PlacesChannels.autocomplete,
          withArgs(ok, {'locationBias': circle, 'locationRestriction': circle}),
        ),
        (
          'circle radius 60 km',
          PlacesChannels.autocomplete,
          withArgs(ok, {
            'locationBias': {...circle, 'radiusMeters': 60000.0},
          }),
        ),
        (
          'unknown area type',
          PlacesChannels.autocomplete,
          withArgs(ok, {
            'locationBias': {'type': 'polygon'},
          }),
        ),
        (
          'rectangle with southwest north of northeast',
          PlacesChannels.autocomplete,
          withArgs(ok, {
            'locationRestriction': {
              'type': 'rectangle',
              'southwest': {'lat': 44.0, 'lng': -80.0},
              'northeast': {'lat': 43.0, 'lng': -79.0},
            },
          }),
        ),
        (
          '16 countries',
          PlacesChannels.autocomplete,
          withArgs(ok, {'countries': codes}),
        ),
        (
          'alpha-3 country "CAN"',
          PlacesChannels.autocomplete,
          withArgs(ok, {
            'countries': ['CAN'],
          }),
        ),
        (
          '6 type filters',
          PlacesChannels.autocomplete,
          withArgs(ok, {'types': List.filled(6, 'airport')}),
        ),
        (
          'regionCode "IND"',
          PlacesChannels.autocomplete,
          withArgs(ok, {'regionCode': 'IND'}),
        ),
        (
          'cancelPrevious "yes"',
          PlacesChannels.autocomplete,
          withArgs(ok, {'cancelPrevious': 'yes'}),
        ),
        (
          'placeDetails without placeId',
          PlacesChannels.placeDetails,
          {'sessionToken': 's'},
        ),
        (
          'placeDetails with unknown field "photos"',
          PlacesChannels.placeDetails,
          {
            'placeId': 'p',
            'sessionToken': 's',
            'fields': ['photos'],
          },
        ),
        (
          'searchNearby without center',
          PlacesChannels.searchNearby,
          {'radiusMeters': 500.0},
        ),
        (
          'searchNearby radius 0',
          PlacesChannels.searchNearby,
          {...nearby, 'radiusMeters': 0.0},
        ),
        (
          'searchNearby maxResults 21',
          PlacesChannels.searchNearby,
          {...nearby, 'maxResults': 21},
        ),
        (
          'searchNearby rankBy "rating"',
          PlacesChannels.searchNearby,
          {...nearby, 'rankBy': 'rating'},
        ),
        ('endSession args that are not a map', PlacesChannels.endSession, 42),
      ];
      for (final (name, method, args) in cases) {
        testWidgets(
          'Scenario Outline: Native rejects bad input before the key check [$name]',
          (tester) async {
            step('When Dart sends $name straight to native "$method"');
            final code = await nativeCode(method, args);
            step('Then native answers INVALID_ARGUMENT (got $code)');
            expect(
              code,
              PlacesErrorCodes.invalidArgument,
              reason: 'native must validate channel args itself',
            );
          },
        );
      }
    },
  );

  group('Feature: Valid requests without a Google key', skip: live, () {
    final cases = <(String, String, Object?)>[
      (
        'autocomplete with every option',
        PlacesChannels.autocomplete,
        withArgs(ok, {
          'countries': codes.take(15).toList(),
          'language': 'fr',
          'origin': center,
          'locationRestriction': {
            'type': 'rectangle',
            'southwest': {'lat': -20.0, 'lng': 170.0},
            'northeast': {'lat': -10.0, 'lng': -170.0},
          },
          'types': ['airport'],
          'regionCode': 'CA',
          'cancelPrevious': true,
        }),
      ),
      (
        'placeDetails with every field',
        PlacesChannels.placeDetails,
        {
          'placeId': 'ChIJpTvG15DL1IkRd8S0KlBVNTI',
          'sessionToken': 'e2e-session',
          'fields': ['name', 'addressComponents', 'viewport', 'plusCode'],
          'regionCode': 'CA',
        },
      ),
      (
        'searchNearby with every option',
        PlacesChannels.searchNearby,
        {
          ...nearby,
          'types': ['electric_vehicle_charging_station'],
          'maxResults': 20,
          'rankBy': 'distance',
          'fields': ['name'],
        },
      ),
      for (final query in [
        'दिल्ली रेलवे स्टेशन',
        'Montréal–Trudeau',
        'مطار دبي',
        '🚉 Union',
        'a' * 1000,
      ])
        (
          'autocomplete "${query.length > 20 ? '${query.length} chars' : query}"',
          PlacesChannels.autocomplete,
          withArgs(ok, {'query': query}),
        ),
    ];
    for (final (name, method, args) in cases) {
      testWidgets(
        'Scenario Outline: Valid input reaches the key check [$name]',
        (tester) async {
          step('Given the example app has the placeholder key YOUR_API_KEY');
          step('When Dart sends $name to native');
          final code = await nativeCode(method, args);
          step('Then native parses it and answers MISSING_API_KEY (got $code)');
          expect(
            code,
            PlacesErrorCodes.missingApiKey,
            reason: 'parsing passed, so only the key is missing',
          );
        },
      );
    }
  });

  group('Feature: Native session lifecycle and robustness', () {
    testWidgets(
      'Scenario: endSession works without a key, for unknown tokens and twice',
      (tester) async {
        step(
          'When Dart ends a session that never searched, then ends it again',
        );
        final first = await nativeCode(PlacesChannels.endSession, {
          'sessionToken': 'never-used',
        });
        final second = await nativeCode(PlacesChannels.endSession, {
          'sessionToken': 'never-used',
        });
        step('Then both succeed (got $first, $second)');
        expect(
          [first, second],
          ['OK', 'OK'],
          reason: 'endSession must be idempotent',
        );
      },
    );

    testWidgets('Scenario: 40 sessions (over the 32 cap) then all ended', (
      tester,
    ) async {
      step('When 40 sessions each search once and then end');
      for (var i = 0; i < 40; i++) {
        await nativeCode(
          PlacesChannels.autocomplete,
          withArgs(ok, {'sessionToken': 'cap-$i'}),
        );
      }
      final ends = [
        for (var i = 0; i < 40; i++)
          await nativeCode(PlacesChannels.endSession, {
            'sessionToken': 'cap-$i',
          }),
      ];
      step('Then every endSession succeeds, including evicted ones');
      expect(ends.toSet(), {'OK'});
    });

    testWidgets('Scenario: A session can search again after it was ended', (
      tester,
    ) async {
      await nativeCode(PlacesChannels.endSession, {'sessionToken': 'reused'});
      step('When a search reuses an ended token');
      final code = await nativeCode(
        PlacesChannels.autocomplete,
        withArgs(ok, {'sessionToken': 'reused'}),
      );
      step('Then native starts a fresh SDK session (got $code)');
      expect(code, anyOf(PlacesErrorCodes.missingApiKey, 'OK'));
    });

    testWidgets('Scenario: An unknown method is UNIMPLEMENTED', (tester) async {
      step('When Dart calls "getApiKey" (forbidden by AGENTS.md)');
      final code = await nativeCode('getApiKey', null);
      step('Then native answers notImplemented → UNIMPLEMENTED (got $code)');
      expect(
        code,
        PlacesErrorCodes.unimplemented,
        reason: 'there is no key-reading method',
      );
    });

    testWidgets('Scenario: 25 concurrent searches all get exactly one reply', (
      tester,
    ) async {
      step('When 25 autocompletes run at once in one session');
      final codes = await Future.wait([
        for (var i = 0; i < 25; i++)
          nativeCode(
            PlacesChannels.autocomplete,
            withArgs(ok, {'query': 'q$i', 'cancelPrevious': true}),
          ),
      ]);
      step(
        'Then all 25 complete within 10 s with a typed code: ${codes.toSet()}',
      );
      expect(codes, hasLength(25));
      expect(
        codes.every(
          (c) => const {
            PlacesErrorCodes.missingApiKey,
            PlacesErrorCodes.cancelled,
            'OK',
          }.contains(c),
        ),
        isTrue,
        reason: 'no reply may be lost or duplicated',
      );
    });
  });

  group('Feature: Autocomplete field on a real device', skip: live, () {
    Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets(
      'Scenario: Without a key the rider sees the error, and can clear it',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HovrPlacesAutocompleteField(
                idleBuilder: (_) => const Text('Home'),
              ),
            ),
          ),
        );
        step('Given the idle slot shows "Home" before typing');
        expect(find.text('Home'), findsOneWidget);
        step('When the rider types "union station" and waits');
        await tester.enterText(find.byType(TextField), 'union station');
        final error = find.textContaining('missing');
        await pumpUntil(tester, error);
        step('Then the missing-key error is shown under the field');
        expect(
          error,
          findsOneWidget,
          reason: 'native MISSING_API_KEY must reach the UI',
        );
        expect(
          find.byType(LinearProgressIndicator),
          findsNothing,
          reason: 'loading bar stuck',
        );
        step('When the rider taps Clear');
        await tester.tap(find.byTooltip('Clear'));
        await pumpUntil(tester, find.text('Home'));
        step('Then the field is empty and "Home" is back');
        expect(find.text('Home'), findsOneWidget);
      },
    );
  });

  group('Feature: Live Google edge cases', skip: !live, () {
    Future<List<PlacePrediction>> search(
      String query, {
      List<String>? countries,
      String? region,
    }) async {
      final session = HovrPlacesSession();
      try {
        return await HovrPlaces.instance.autocomplete(
          query: query,
          session: session,
          countries: countries,
          regionCode: region,
        );
      } finally {
        await session.close();
      }
    }

    testWidgets('Scenario: Hindi query returns Indian results', (tester) async {
      final hits = await search(
        'दिल्ली रेलवे स्टेशन',
        countries: ['IN'],
        region: 'IN',
      );
      step('Then: ${hits.map((h) => h.primaryText).join(' | ')}');
      expect(hits, isNotEmpty);
    });

    testWidgets('Scenario: Accented French query returns Montréal', (
      tester,
    ) async {
      final hits = await search('Montréal–Trudeau', countries: ['CA']);
      expect(hits.map((h) => h.fullText).join(), contains('Montr'));
    });

    testWidgets(
      'Scenario: Nonsense query returns an empty list, not an error',
      (tester) async {
        expect(await search('qzxjvwk qzxjvwk'), isEmpty);
      },
    );

    testWidgets('Scenario: Restriction to Toronto never returns Delhi', (
      tester,
    ) async {
      final session = HovrPlacesSession();
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'connaught place',
        session: session,
        locationRestriction: const PlacesCircle(
          center: PlacesLatLng(43.65, -79.38),
          radiusMeters: 50000,
        ),
      );
      await session.close();
      expect(hits.where((h) => h.fullText.contains('Delhi')), isEmpty);
    });

    testWidgets('Scenario: A made-up place id fails with a native code', (
      tester,
    ) async {
      final session = HovrPlacesSession();
      try {
        await HovrPlaces.instance.fetchDetails(
          placeId: 'ChIJ_not_a_real_place_id_000',
          session: session,
        );
        fail('expected PlacesException');
      } on PlacesException catch (error) {
        step('Then ${error.code} nativeCode=${error.nativeCode}');
        expect(error.code, PlacesErrorCodes.placeError);
        expect(
          error.nativeCode,
          isNotNull,
          reason: 'support needs the Google status',
        );
      } finally {
        await session.close();
      }
    });

    testWidgets('Scenario: EV chargers near Union Station respect maxResults', (
      tester,
    ) async {
      final places = await HovrPlaces.instance.searchNearby(
        area: const PlacesCircle(
          center: PlacesLatLng(43.6453, -79.3806),
          radiusMeters: 2000,
        ),
        types: const ['electric_vehicle_charging_station'],
        maxResults: 5,
        rankByDistance: true,
      );
      step('Then ${places.length} chargers');
      expect(places.length, lessThanOrEqualTo(5));
    });
  });
}
