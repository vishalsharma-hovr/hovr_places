## 0.2.0

- iOS podspec requires `GooglePlaces >= 10.0` (was `>= 9.0`). Verified against 10.0.0, 10.1.0 (driver app pin) and 10.15.0.
- New `searchNearby` channel method and `HovrPlaces.searchNearby` / `nearestPlace` ("use my current location").
- `fetchDetails(fields: {...})`: optional billed fields `name`, `addressComponents`, `viewport`, `plusCode`; `PlaceDetails.component('locality')` reads city / postal code.
- `autocomplete(types: [...])` (up to 5) and `regionCode` (also on `HovrPlacesConfig`).
- `PlacePrediction.types`, `primaryMatches`; `isAirport` on predictions and details.
- `autocomplete(cancelPrevious: true)` (Android): cancels this session's in-flight autocomplete, which fails with new code `CANCELLED`. Off by default; `HovrPlacesAutocompleteField` turns it on.
- `PLACE_ERROR` now carries Google's native status code: `PlacesException.nativeCode` (e.g. 9011 when the Places SDK rejects the key).
- `HovrPlaces.onUsage` reports every native call (method, elapsed, session, error code).
- `HovrPlacesAutocompleteField`: bold matched text, plane icon for airports, `types`, `idleBuilder` (e.g. Home / Work / recents).
- Example app: iOS 16 Podfile, key from git-ignored `local.properties` / `Secrets.xcconfig`, opt-in live integration tests (`doc/DEVICE_TESTING.md`).
- CI workflow: Dart, Kotlin and Swift tests, contract check, iOS example build.

- `autocomplete` accepts `origin`, `locationBias` and `locationRestriction` (`PlacesLatLng`, `PlacesCircle`, `PlacesRectangle`). With an origin, `PlacePrediction.distanceMeters` is filled in; `sortByDistance: true` orders results nearest first (unknown distances last, ties keep Google's order).
- `HovrPlacesAutocompleteField` takes `origin`, `locationBias`, `locationRestriction` and `sortByDistance`, and shows "850 m" / "1.2 km" on each row.

- **Breaking:** `HovrPlacesConfig.countries` now defaults to `[]` (no filter) instead of `['CA', 'IN']`. Pass countries explicitly.
- **Breaking (Google Cloud):** Android now uses Places API (New) like iOS. The host key needs "Places API (New)" enabled.
- `language` is now applied on Android (re-initializes the Places SDK when it changes). iOS still follows the device language.
- `placeDetails` returns `PLACE_ERROR` when a place has no coordinates instead of `0, 0`; Dart also rejects out-of-range coordinates.
- iOS place details use `fetchPlace(with:)` instead of the deprecated `fetchPlaceFromPlaceID`.
- Android reuses one `PlacesClient` instead of creating one per request.
- Native session stores keep at most 32 sessions, dropping the oldest.
- `HovrPlacesAutocompleteField`: drops stale responses, no longer changes `HovrPlaces.instance` config, honours `minQueryLength` (default 2), shows a loading bar, clear button and "no results" text, accepts `itemBuilder`, and no longer throws if `endSession` fails on dispose.

## 0.1.0

- Initial plugin: Places autocomplete, place details, and session end over `com.hovr/places`.
- Dart owns session UUIDs; native maps them to Places SDK session tokens.
- API key stays in host AndroidManifest / Info.plist (never Dart, never the channel).
