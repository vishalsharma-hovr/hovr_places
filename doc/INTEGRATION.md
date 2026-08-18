# Integration guide

## 1. Add dependency

**Local plugin development:**

Resolve the clone from `$HOME`. Do not commit `/Users/<name>/...`.

```yaml
dependencies:
  hovr_places:
    path: ~/Documents/hovr-packages/hovr_places
```

`pubspec.yaml` `path:` does not expand `~`. From the host app root, convert it to a relative path and use that (do not commit an absolute home path):

```bash
python3 -c "from pathlib import Path; print((Path.home()/'Documents/hovr-packages/hovr_places').relative_to(Path('.').resolve()))"
```

**Later (git, after the package is published):**

```yaml
dependencies:
  hovr_places:
    git:
      url: https://github.com/vishalsharma-hovr/hovr_places.git
      ref: v0.1.0
```

Run `fvm flutter pub get` from the host app root. Do **not** put the Google API key in Dart, `--dart-define`, or pubspec.

## 2. Android host setup

Add the key to `android/app/src/main/AndroidManifest.xml` inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_KEY"/>
```

Enable **Places API** (Places SDK) for that key in Google Cloud Console. Restrict by Android package name + SHA-1.

The plugin reads `com.google.android.geo.API_KEY`, then `GOOGLE_MAPS_API_KEY`, the same way `hovr_ride_map` does. Placeholders like `YOUR_API_KEY` or `$(GOOGLE_MAPS_API_KEY)` are treated as missing.

## 3. iOS host setup

```xml
<!-- ios/Runner/Info.plist -->
<key>GOOGLE_MAPS_API_KEY</key>
<string>YOUR_KEY</string>
```

The plugin calls `GMSPlacesClient.provideAPIKey` from that plist value. Host apps that already call `GMSServices.provideAPIKey` for Maps still need Places enabled on the same key.

The plugin podspec depends on `GooglePlaces` (`>= 9.0`). After adding the Flutter dependency, run `cd ios && pod install`.

Enable Places for the iOS bundle id in Google Cloud Console.

## 4. Dart usage

```dart
import 'package:hovr_places/hovr_places.dart';

HovrPlaces.instance.configure(
  const HovrPlacesConfig(countries: ['CA', 'IN'], language: 'en'),
);

final session = HovrPlacesSession();
final hits = await HovrPlaces.instance.autocomplete(
  query: 'union station',
  session: session,
);
final place = await HovrPlaces.instance.fetchDetails(
  placeId: hits.first.placeId,
  session: session,
);
await session.close(); // or HovrPlaces.instance.endSession(session)
```

Optional UI (no trip/pickup types):

```dart
HovrPlacesAutocompleteField(
  onSelected: (hit) { /* fetchDetails with a shared session */ },
)
```

## Out of scope (host app)

- Trip / FindRide / neighbour booking types
- Saved-places SQLite
- Passing the API key through Dart
