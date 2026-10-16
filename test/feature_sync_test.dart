import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when a .feature scenario has no test named after it, so the
/// feature files cannot drift from what is actually tested.
void main() {
  test('Every scenario in test/features has a matching test', () {
    final testSources = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final missing = <String>[];
    final features = Directory(
      'test/features',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.feature'));
    for (final file in features) {
      for (final line in file.readAsLinesSync().map((l) => l.trim())) {
        if (line.startsWith('Scenario') && !testSources.contains(line)) {
          missing.add('${file.path}: $line');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These scenarios have no test with the same name:\n'
          '${missing.join('\n')}',
    );
  });
}
