import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

const _debounce = Duration(milliseconds: 300);

Widget _app({ValueChanged<PlacePrediction>? onSelected, HovrPlacesSession? s}) {
  return MaterialApp(
    home: Scaffold(
      body: HovrPlacesAutocompleteField(onSelected: onSelected, session: s),
    ),
  );
}

Future<void> _typeAndWait(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(_debounce);
  await tester.pump();
}

List<MethodCall> _autocompleteCalls(List<MethodCall> calls) =>
    calls.where((c) => c.method == PlacesChannels.autocomplete).toList();

List<MethodCall> _unionStationNative() => mockNative(
  (_) async =>
      predictionsResult([prediction('p1', 'Union Station', 'Toronto')]),
);

void main() {
  usePlacesChannel();

  group('Feature: Autocomplete field widget', () {
    testWidgets('Scenario: Typing shows predictions after the debounce', (
      tester,
    ) async {
      step('Given native returns "Union Station"');
      _unionStationNative();
      await tester.pumpWidget(_app());
      step('When the rider types "union" and waits 300 ms');
      await _typeAndWait(tester, 'union');
      step('Then "Union Station" is shown in the list');
      expect(
        find.text('Union Station'),
        findsOneWidget,
        reason: 'the prediction must appear once the debounce fires',
      );
    });

    testWidgets('Scenario: Typing faster than the debounce sends one request', (
      tester,
    ) async {
      final calls = _unionStationNative();
      await tester.pumpWidget(_app());
      step('When the rider types "u", "un", "uni" within 300 ms');
      for (final text in <String>['u', 'un', 'uni']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(_debounce);
      step(
        'Then native receives exactly one autocomplete call with query "uni"',
      );
      final searches = _autocompleteCalls(calls);
      expect(
        searches,
        hasLength(1),
        reason: 'each keystroke must not be a billed request',
      );
      expect(argsOf(searches.single)['query'], 'uni');
    });

    testWidgets(
      'Scenario: Clearing the text clears the results without calling native',
      (tester) async {
        step('Given the list shows "Union Station"');
        final calls = _unionStationNative();
        await tester.pumpWidget(_app());
        await _typeAndWait(tester, 'union');
        expect(find.text('Union Station'), findsOneWidget);
        step('When the rider clears the text');
        await _typeAndWait(tester, '');
        step('Then the list is empty');
        expect(find.byType(ListTile), findsNothing, reason: 'old hits remain');
        step('And native receives no new autocomplete call');
        expect(_autocompleteCalls(calls), hasLength(1));
      },
    );

    testWidgets('Scenario: Tapping a prediction reports it to the app', (
      tester,
    ) async {
      step('Given the list shows "Union Station"');
      _unionStationNative();
      PlacePrediction? picked;
      await tester.pumpWidget(_app(onSelected: (hit) => picked = hit));
      await _typeAndWait(tester, 'union');
      step('When the rider taps "Union Station"');
      await tester.tap(find.text('Union Station'));
      step('Then onSelected receives place id "p1"');
      expect(picked?.placeId, 'p1', reason: 'the app needs the id for details');
    });

    testWidgets('Scenario: A native error is shown under the field', (
      tester,
    ) async {
      step(
        'Given native fails with "PLACE_ERROR" and message '
        '"Places SDK request failed"',
      );
      mockNative((MethodCall call) async {
        if (call.method != PlacesChannels.autocomplete) return null;
        throw PlatformException(
          code: PlacesErrorCodes.placeError,
          message: 'Places SDK request failed',
        );
      });
      await tester.pumpWidget(_app());
      step('When the rider types "union" and waits 300 ms');
      await _typeAndWait(tester, 'union');
      step('Then "Places SDK request failed" is shown');
      expect(
        find.text('Places SDK request failed'),
        findsOneWidget,
        reason: 'the rider must see why there are no results',
      );
    });

    testWidgets("Scenario: Leaving the screen closes the field's own session", (
      tester,
    ) async {
      step("Given the field created its own session and searched once");
      final calls = _unionStationNative();
      await tester.pumpWidget(_app());
      await _typeAndWait(tester, 'union');
      final token = argsOf(_autocompleteCalls(calls).single)['sessionToken'];
      step('When the field is removed from the screen');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      step('Then native receives "endSession" with the same token');
      final ends = calls.where((c) => c.method == PlacesChannels.endSession);
      expect(ends, hasLength(1), reason: 'native SDK token would leak');
      expect(argsOf(ends.single)['sessionToken'], token);
    });

    testWidgets(
      'Scenario: A session passed in by the app is not closed by the field',
      (tester) async {
        step('Given the app passes session "app-sess" to the field');
        final calls = _unionStationNative();
        await tester.pumpWidget(_app(s: HovrPlacesSession(token: 'app-sess')));
        step('When the field is removed from the screen');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        step('Then native receives no "endSession" call');
        expect(
          methodsOf(calls),
          isNot(contains(PlacesChannels.endSession)),
          reason: 'the app still needs this session for place details',
        );
      },
    );

    testWidgets(
      'Scenario: A slow old response does not replace newer results',
      (tester) async {
        step('Given native answers "toro" slowly and "toronto" quickly');
        final slow = Completer<Object?>();
        mockNative((MethodCall call) {
          if (argsOf(call)['query'] == 'toro') return slow.future;
          return Future.value(
            predictionsResult([prediction('p2', 'Toronto', 'ON')]),
          );
        });
        await tester.pumpWidget(_app());
        step('When the rider types "toro" then "toronto"');
        await _typeAndWait(tester, 'toro');
        await _typeAndWait(tester, 'toronto');
        step('And the slow "toro" answer arrives last');
        slow.complete(predictionsResult([prediction('p1', 'Toro', 'Spain')]));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        step('Then the list still shows the "toronto" results');
        expect(find.text('Toronto'), findsOneWidget);
        expect(find.text('Toro'), findsNothing, reason: 'stale answer won');
      },
    );

    testWidgets(
      'Scenario: A query shorter than the minimum length is not sent',
      (tester) async {
        step('Given the minimum query length is 2');
        final calls = _unionStationNative();
        await tester.pumpWidget(_app());
        step('When the rider types "u" and waits 300 ms');
        await _typeAndWait(tester, 'u');
        step('Then native receives no autocomplete call');
        expect(
          _autocompleteCalls(calls),
          isEmpty,
          reason: 'one letter is a billed request with useless results',
        );
      },
    );

    testWidgets(
      'Scenario: A search with no matches shows the no-results message',
      (tester) async {
        step('Given native returns no predictions');
        mockNative((_) async => predictionsResult([]));
        await tester.pumpWidget(_app());
        step('When the rider types "zzzz" and waits 300 ms');
        await _typeAndWait(tester, 'zzzz');
        step('Then "No places found" is shown');
        expect(
          find.text('No places found'),
          findsOneWidget,
          reason: 'an empty list alone looks like the app is still loading',
        );
      },
    );

    testWidgets('Scenario: The clear button empties the field and the list', (
      tester,
    ) async {
      step('Given the list shows "Union Station"');
      _unionStationNative();
      await tester.pumpWidget(_app());
      await _typeAndWait(tester, 'union');
      expect(find.text('Union Station'), findsOneWidget);
      step('When the rider taps the clear button');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump(_debounce);
      await tester.pump();
      step('Then the field is empty');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty, reason: 'text was not cleared');
      step('And the list is empty');
      expect(find.byType(ListTile), findsNothing, reason: 'old hits remain');
    });

    testWidgets(
      "Scenario: The field's config does not change the app-wide config",
      (tester) async {
        step('Given the field is given countries "IN"');
        const fieldConfig = HovrPlacesConfig(countries: <String>['IN']);
        step('When the field is shown');
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HovrPlacesAutocompleteField(config: fieldConfig),
            ),
          ),
        );
        step('Then the app-wide config countries are still empty');
        expect(
          HovrPlaces.instance.config.countries,
          isEmpty,
          reason: 'one screen must not change search filters for the whole app',
        );
      },
    );

    testWidgets(
      'Scenario: A loading bar is shown while a search is in flight',
      (tester) async {
        step('Given native has not answered yet');
        final answer = Completer<Object?>();
        mockNative((MethodCall call) async {
          if (call.method != PlacesChannels.autocomplete) return null;
          return answer.future;
        });
        await tester.pumpWidget(_app());
        step('When the rider types "union" and waits 300 ms');
        await _typeAndWait(tester, 'union');
        step('Then a loading bar is shown');
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        step('And it disappears once native answers');
        answer.complete(predictionsResult([]));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(
          find.byType(LinearProgressIndicator),
          findsNothing,
          reason: 'loading bar stuck after native answered',
        );
      },
    );

    testWidgets('Scenario: A custom itemBuilder renders each prediction', (
      tester,
    ) async {
      step(
        'Given the app passes an itemBuilder that shows "-> <primary text>"',
      );
      _unionStationNative();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HovrPlacesAutocompleteField(
              itemBuilder: (context, hit, onTap) => TextButton(
                onPressed: onTap,
                child: Text('-> ${hit.primaryText}'),
              ),
            ),
          ),
        ),
      );
      step('When the rider types "union" and waits 300 ms');
      await _typeAndWait(tester, 'union');
      step('Then "-> Union Station" is shown');
      expect(find.text('-> Union Station'), findsOneWidget);
    });

    testWidgets(
      'Scenario: A failed endSession while leaving the screen does not crash',
      (tester) async {
        step('Given native fails every call with "PLACE_ERROR"');
        mockNative(
          (_) async =>
              throw PlatformException(code: PlacesErrorCodes.placeError),
        );
        await tester.pumpWidget(_app());
        await _typeAndWait(tester, 'union');
        step('When the field is removed from the screen');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        step('Then no error reaches the app');
        expect(
          tester.takeException(),
          isNull,
          reason: 'a failed endSession during dispose must be swallowed',
        );
      },
    );

    testWidgets('Scenario: The field sends its origin and sorts by distance', (
      tester,
    ) async {
      step(
        'Given the field has origin 43.65, -79.38 and sortByDistance enabled',
      );
      step('And native returns "Far" at 5000 m and "Near" at 300 m');
      final calls = mockNative(
        (_) async => predictionsResult([
          prediction('far', 'Far', 'ON', distanceMeters: 5000),
          prediction('near', 'Near', 'ON', distanceMeters: 300),
        ]),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HovrPlacesAutocompleteField(
              origin: PlacesLatLng(43.65, -79.38),
              sortByDistance: true,
            ),
          ),
        ),
      );
      step('When the rider types "union" and waits 300 ms');
      await _typeAndWait(tester, 'union');
      step('Then native receives the origin');
      expect(
        argsOf(_autocompleteCalls(calls).single)['origin'],
        <String, Object>{'lat': 43.65, 'lng': -79.38},
        reason: 'the field must forward its origin',
      );
      step('And "Near" is listed above "Far"');
      expect(
        tester.getTopLeft(find.text('Near')).dy,
        lessThan(tester.getTopLeft(find.text('Far')).dy),
        reason: 'nearest place must be first in the list',
      );
    });

    testWidgets(
      'Scenario: Distances are shown as meters under 1 km and kilometers above',
      (tester) async {
        step('Given native returns "Near" at 850 m and "Far" at 1234 m');
        mockNative(
          (_) async => predictionsResult([
            prediction('near', 'Near', 'ON', distanceMeters: 850),
            prediction('far', 'Far', 'ON', distanceMeters: 1234),
          ]),
        );
        await tester.pumpWidget(_app());
        step('When the rider types "union" and waits 300 ms');
        await _typeAndWait(tester, 'union');
        step('Then "850 m" and "1.2 km" are shown');
        expect(find.text('850 m'), findsOneWidget, reason: 'meters label');
        expect(find.text('1.2 km'), findsOneWidget, reason: 'kilometers label');
      },
    );

    testWidgets('Scenario: The idle builder is shown before the rider types', (
      tester,
    ) async {
      step('Given the app passes an idleBuilder showing "Home"');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HovrPlacesAutocompleteField(
              idleBuilder: (_) => const Text('Home'),
            ),
          ),
        ),
      );
      step('When the field is shown');
      step('Then "Home" is shown');
      expect(find.text('Home'), findsOneWidget, reason: 'recents slot');
    });

    testWidgets('Scenario: The idle builder is hidden once a search runs', (
      tester,
    ) async {
      step('Given the app passes an idleBuilder showing "Home"');
      _unionStationNative();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HovrPlacesAutocompleteField(
              idleBuilder: (_) => const Text('Home'),
            ),
          ),
        ),
      );
      step('When the rider types "union" and waits 300 ms');
      await _typeAndWait(tester, 'union');
      step('Then "Home" is not shown');
      expect(
        find.text('Home'),
        findsNothing,
        reason: 'results replace recents',
      );
    });

    testWidgets('Scenario: An airport prediction shows a plane icon', (
      tester,
    ) async {
      step('Given native returns "Toronto Pearson" with types "airport"');
      mockNative(
        (_) async => predictionsResult([
          <String, Object>{
            ...prediction('yyz', 'Toronto Pearson', 'Mississauga'),
            'types': ['airport'],
          },
        ]),
      );
      await tester.pumpWidget(_app());
      step('When the rider types "pearson" and waits 300 ms');
      await _typeAndWait(tester, 'pearson');
      step('Then a plane icon is shown');
      expect(find.byIcon(Icons.flight), findsOneWidget);
    });

    testWidgets('Scenario: The field opts in to native cancellation', (
      tester,
    ) async {
      final calls = _unionStationNative();
      await tester.pumpWidget(_app());
      step('When the rider types "union" and waits 300 ms');
      await _typeAndWait(tester, 'union');
      step('Then native receives cancelPrevious true');
      expect(
        argsOf(_autocompleteCalls(calls).single)['cancelPrevious'],
        isTrue,
        reason: 'the field drops stale responses, so cancelling saves data',
      );
    });
  });
}
