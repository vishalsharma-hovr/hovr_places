import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';
import 'package:hovr_places/src/channels/places_payload.dart';

const placesChannel = MethodChannel(PlacesChannels.name);

/// Prints a Given/When/Then line so the test log reads like the .feature file.
void step(String text) => debugPrint('    $text');

/// Resets [HovrPlaces.instance] onto [placesChannel] around every test.
void usePlacesChannel() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => HovrPlaces.debugReset(channel: placesChannel));
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(placesChannel, null);
    HovrPlaces.debugReset();
  });
}

/// Fakes the native side with [reply] and records every call it receives.
List<MethodCall> mockNative(Future<Object?> Function(MethodCall call) reply) {
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(placesChannel, (MethodCall call) {
        calls.add(call);
        return reply(call);
      });
  return calls;
}

Map<String, Object?> argsOf(MethodCall call) =>
    asStringKeyedMap(call.arguments, '${call.method} args');

List<String> methodsOf(List<MethodCall> calls) =>
    calls.map((call) => call.method).toList();

Map<String, Object> prediction(
  String id,
  String primary,
  String secondary, {
  int? distanceMeters,
}) => <String, Object>{
  'placeId': id,
  'primaryText': primary,
  'secondaryText': secondary,
  'fullText': '$primary, $secondary',
  'distanceMeters': ?distanceMeters,
};

Map<String, Object> predictionsResult(List<Map<String, Object>> items) =>
    <String, Object>{'predictions': items};

Matcher throwsPlacesCode(String code) => throwsA(
  isA<PlacesException>().having((e) => e.code, 'PlacesException.code', code),
);
