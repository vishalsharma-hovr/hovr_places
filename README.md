# hovr_places

Reusable Flutter plugin for **Google Places autocomplete** and **place details**. Native SDKs run on Android and iOS over MethodChannel `com.hovr/places`. The API key never crosses the channel.

## Usage

```dart
import 'package:hovr_places/hovr_places.dart';

final session = HovrPlacesSession();
final hits = await HovrPlaces.instance.autocomplete(
  query: 'union station',
  session: session,
);
final place = await HovrPlaces.instance.fetchDetails(
  placeId: hits.first.placeId,
  session: session,
);
await session.close();
```

Configure countries / language / field debounce in Dart. Inject the Google key only in the host AndroidManifest / Info.plist — see [doc/INTEGRATION.md](doc/INTEGRATION.md).

## Local development

Point the host app at your clone. Resolve the path from `$HOME` — do not commit `/Users/<name>/...`.

```yaml
hovr_places:
  path: ~/Documents/hovr-packages/hovr_places
```

`pubspec.yaml` `path:` does not expand `~`. From the host app root, convert it to a relative path and use that (do not commit an absolute home path):

```bash
python3 -c "from pathlib import Path; print((Path.home()/'Documents/hovr-packages/hovr_places').relative_to(Path('.').resolve()))"
```

## Validation

```bash
cd ~/Documents/hovr-packages/hovr_places
dart analyze --fatal-warnings lib test example/lib tool
dart run tool/check_channel_contract.dart
fvm flutter test
cd example/android && ./gradlew :hovr_places:testDebugUnitTest
```

## Publishing

Bump `version`, tag (e.g. `v0.1.0`), publish to GitHub, pin consumer apps to the git `ref`.
