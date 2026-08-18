// Verifies Dart, Kotlin, Swift, and CHANNEL_CONTRACT stay aligned.
import 'dart:io';

void main() {
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Run from hovr_places package root');
    exit(1);
  }

  final dart = File('lib/src/channels/places_channels.dart').readAsStringSync();
  final kotlin = File(
    'android/src/main/kotlin/com/hovr/hovr_places/PlacesChannelConstants.kt',
  ).readAsStringSync();
  final swift = File(
    'ios/hovr_places/Sources/hovr_places/PlacesChannelConstants.swift',
  ).readAsStringSync();
  final doc = File('doc/CHANNEL_CONTRACT.md').readAsStringSync();
  final sources = '$dart$kotlin$swift$doc';

  const channelName = 'com.hovr/places';
  const methods = <String>['autocomplete', 'placeDetails', 'endSession'];
  const errors = <String>[
    'INVALID_ARGUMENT',
    'MISSING_API_KEY',
    'PLACE_ERROR',
    'UNIMPLEMENTED',
  ];

  var failed = false;

  if (!dart.contains("'$channelName'") && !dart.contains('"$channelName"')) {
    stderr.writeln('Missing in Dart: $channelName');
    failed = true;
  }
  if (!kotlin.contains('"$channelName"')) {
    stderr.writeln('Missing in Kotlin: $channelName');
    failed = true;
  }
  if (!swift.contains('"$channelName"')) {
    stderr.writeln('Missing in Swift: $channelName');
    failed = true;
  }
  if (!doc.contains(channelName)) {
    stderr.writeln('Missing in CHANNEL_CONTRACT.md: $channelName');
    failed = true;
  }

  for (final method in methods) {
    if (!dart.contains("'$method'")) {
      stderr.writeln('Missing in Dart: $method');
      failed = true;
    }
    if (!kotlin.contains('"$method"')) {
      stderr.writeln('Missing in Kotlin: $method');
      failed = true;
    }
    if (!swift.contains('"$method"')) {
      stderr.writeln('Missing in Swift: $method');
      failed = true;
    }
    if (!doc.contains('`$method`') && !doc.contains(method)) {
      stderr.writeln('Missing in CHANNEL_CONTRACT.md: $method');
      failed = true;
    }
  }

  for (final code in errors) {
    if (!sources.contains(code)) {
      stderr.writeln('Missing error code: $code');
      failed = true;
    }
  }

  const forbidden = 'get-api-key';
  if (dart.contains(forbidden) ||
      kotlin.contains(forbidden) ||
      swift.contains(forbidden)) {
    stderr.writeln('Forbidden method present: $forbidden');
    failed = true;
  }

  if (failed) {
    exit(1);
  }
  stdout.writeln(
    'Channel contract OK ($channelName, ${methods.length} methods, ${errors.length} errors).',
  );
}
