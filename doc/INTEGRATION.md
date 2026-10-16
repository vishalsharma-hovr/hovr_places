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

Enable **Places API (New)** for that key in Google Cloud Console. Restrict by Android package name + SHA-1.

The plugin reads `com.google.android.geo.API_KEY`, then `GOOGLE_MAPS_API_KEY`, the same way `hovr_ride_map` does. Placeholders like `YOUR_API_KEY` or `$(GOOGLE_MAPS_API_KEY)` are treated as missing.

## 3. iOS host setup

```xml
<!-- ios/Runner/Info.plist -->
<key>GOOGLE_MAPS_API_KEY</key>
<string>YOUR_KEY</string>
```

The plugin calls `GMSPlacesClient.provideAPIKey` from that plist value. Host apps that already call `GMSServices.provideAPIKey` for Maps still need Places enabled on the same key.

The plugin podspec depends on `GooglePlaces` (`>= 9.0`). After adding the Flutter dependency, run `cd ios && pod install`.

Enable **Places API (New)** for the key in Google Cloud Console (both platforms use it).

## 4. Dart usage

```dart
import 'package:hovr_places/hovr_places.dart';

HovrPlaces.instance.configure(
  // countries defaults to [] (no filter). language is Android-only; iOS uses the device language.
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

Nearest results first, limited to a service area:

```dart
final hits = await HovrPlaces.instance.autocomplete(
  query: 'union',
  session: session,
  origin: PlacesLatLng(position.latitude, position.longitude),
  locationRestriction: const PlacesRectangle(
    southwest: PlacesLatLng(43.58, -79.64),
    northeast: PlacesLatLng(43.86, -79.12),
  ),
  sortByDistance: true,
);
// hits.first.distanceMeters → straight-line meters from origin
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

## 5. HOVR rider and driver apps

Both apps already declare `hovr_places` (git `ref: v0.1.1`), supply the key as `com.google.android.geo.API_KEY` / `GOOGLE_MAPS_API_KEY`, and pass `countries: ['CA', 'IN']` where they configure it. Moving to `0.2.0` needs no Dart changes.

Before bumping the `ref`:

1. **Places API (New)** must be enabled for the Android *and* iOS keys of both apps (Android switched from the legacy API in 0.2.0). A rejected key shows up as `PLACE_ERROR` with `PlacesException.nativeCode == 9011` on Android.
2. iOS: `GooglePlaces >= 10.0`. The driver's `Podfile.lock` (10.1.0) and the rider's (10.10.0) already satisfy it; no `pod update` needed.
3. If you handle errors yourself (like the driver's `NeighbourPlacesSearchCubit`), leave `cancelPrevious` off unless stale `CANCELLED` errors are dropped before they reach logs or UI.

### Replacing the rider's REST autocomplete

`lib/core/platform/event_channels/places_search_service.dart` maps 1:1:

| Rider REST today | `hovr_places` |
|---|---|
| `locationrestriction=circle:50000@lat,lng` | `locationRestriction: PlacesCircle(center: here, radiusMeters: 50000)` |
| `origin=lat,lng` + `distance_meters` | `origin: here` + `PlacePrediction.distanceMeters` |
| `nearestPlacePredictions` sort (unknown distance last) | `sortByDistance: true` |
| `components=country:ca` | `countries: ['CA']` |
| `types`, `structured_formatting` | `types`, `primaryText` / `secondaryText` |
| `details/json` → lat, lng, `formatted_address` | `fetchDetails(...)` → `latitude`, `longitude`, `formattedAddress` (same session) |
| "one native search at a time" event-channel guard | Not needed: MethodChannel replies go to their own caller |
| REST fallback on native error 9011 | Not available by design (the key never enters Dart). Fix the key restriction instead; detect it with `nativeCode == 9011`. |

```dart
final hits = await HovrPlaces.instance.autocomplete(
  query: query,
  session: session,
  countries: [country],
  origin: here,
  locationRestriction: PlacesCircle(center: here, radiusMeters: 50000),
  sortByDistance: true,
);
```
