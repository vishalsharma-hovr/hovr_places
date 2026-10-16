import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';

import 'support/places_harness.dart';

void main() {
  usePlacesChannel();

  final session = HovrPlacesSession(token: 'sess-1');

  void nativeReturnsMatches(String text, List<List<int>> m) {
    mockNative(
      (_) async => predictionsResult([
        <String, Object>{
          ...prediction('p1', text, 'Toronto'),
          'primaryMatches': m,
        },
      ]),
    );
  }

  group('Feature: Match highlighting', () {
    test('Scenario: Match ranges are mapped from native', () async {
      step('Given native returns "Union Station" with match 0, 5');
      nativeReturnsMatches('Union Station', [
        [0, 5],
      ]);
      step('When the app searches for "union"');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'union',
        session: session,
      );
      step('Then the prediction has primaryMatches (0, 5)');
      expect(hits.single.primaryMatches, [(0, 5)]);
    });

    test('Scenario: Out-of-range match ranges are dropped', () async {
      step('Given native returns "Union" with matches 0, 3 and 2, 99');
      nativeReturnsMatches('Union', [
        [0, 3],
        [2, 99],
      ]);
      step('When the app searches for "uni"');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'uni',
        session: session,
      );
      step('Then the prediction has primaryMatches (0, 3) only');
      expect(hits.single.primaryMatches, [
        (0, 3),
      ], reason: 'a bad range must not crash substring() in the widget');
    });

    testWidgets('Scenario: Matched text is shown in bold', (tester) async {
      step('Given native returns "Union Station" with match 0, 5');
      nativeReturnsMatches('Union Station', [
        [0, 5],
      ]);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HovrPlacesAutocompleteField())),
      );
      step('When the rider types "union" and waits 300 ms');
      await tester.enterText(find.byType(TextField), 'union');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      step('Then "Union" is bold and " Station" is not');
      final title = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == 'Union Station',
        ),
      );
      final parts = (title.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(parts.map((p) => p.text), ['Union', ' Station']);
      expect(parts[0].style?.fontWeight, FontWeight.bold, reason: 'match');
      expect(parts[1].style?.fontWeight, isNull, reason: 'non-match');
    });
  });
}
