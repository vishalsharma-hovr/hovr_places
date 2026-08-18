import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places_example/main.dart';

void main() {
  testWidgets('example shows places field', (WidgetTester tester) async {
    await tester.pumpWidget(const HovrPlacesExampleApp());
    expect(find.text('hovr_places example'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
