# Channel contract

Channel name: `com.hovr/places`

There is **no** `get-api-key` method. Native code reads `com.google.android.geo.API_KEY` (Android) or `GOOGLE_MAPS_API_KEY` (iOS). The key never crosses the channel and must never be logged.

## Methods

| Method | Args | Result |
|--------|------|--------|
| `autocomplete` | `{ query, sessionToken, countries?, language?, origin?, locationBias?, locationRestriction?, types?, regionCode?, cancelPrevious? }` | `{ predictions: [{ placeId, primaryText, secondaryText, fullText, distanceMeters?, types, primaryMatches }] }` |
| `placeDetails` | `{ placeId, sessionToken, fields?, regionCode? }` | `Place` |
| `searchNearby` | `{ center: { lat, lng }, radiusMeters, types?, maxResults?, rankBy?, fields?, regionCode? }` | `{ places: [Place] }` |
| `endSession` | `{ sessionToken }` | `null` |

`Place` is `{ placeId, lat, lng, formattedAddress, types }` plus, only when that name is in `fields`:
`name`, `addressComponents: [{ name, shortName, types }]`, `viewport: { southwest: { lat, lng }, northeast: { lat, lng } }`, `plusCode: { globalCode, compoundCode }`. Allowed `fields`: `name`, `addressComponents`, `viewport`, `plusCode`; any other value is `INVALID_ARGUMENT`.

### Autocomplete extras

- `countries`: up to 15 two-letter codes (Google's `includedRegionCodes` limit).
- `types`: 1–5 Google place types (e.g. `airport`, `street_address`).
- Google returns at most **5** predictions per request, so `sortByDistance` reorders those 5; it cannot surface a nearer 6th place.
- Rectangles may cross the 180° meridian: `southwest.lng > northeast.lng` is valid.
- `regionCode`: 2-letter CLDR code. Per request on both platforms for autocomplete and `searchNearby`; for `placeDetails` Android only (iOS has no option).
- `primaryMatches`: `[[offset, length], …]` ranges of `primaryText` that match the query, in UTF-16 code units. Dart drops ranges outside the text.
- `cancelPrevious` (bool, default `false`): Android only. When `true`, a newer `autocomplete` with `cancelPrevious` in the same session, or `endSession`, cancels the in-flight one, which fails with `CANCELLED`. Off by default so 0.1.x callers never see `CANCELLED`. iOS validates it but cannot cancel.

### Nearby search

- `searchNearby` is **not** session-billed; it takes no `sessionToken`.
- `radiusMeters` in (0, 50000]; `types` 1–50 entries; `maxResults` 1–20; `rankBy` is `"popularity"` (default) or `"distance"`.
- Places without valid coordinates are dropped from `places`.
- Dart's `nearestPlace(point)` is `searchNearby` with `maxResults: 1, rankBy: "distance"` and a 100 m radius by default.

### Location arguments

- `origin`: `{ lat, lng }`. Google then returns `distanceMeters` (straight-line, integer meters) per prediction; it is `null`/absent otherwise.
- `locationBias` / `locationRestriction`: an area, **at most one of the two** per request:
  - `{ type: "circle", center: { lat, lng }, radiusMeters }` with `0 < radiusMeters <= 50000`
  - `{ type: "rectangle", southwest: { lat, lng }, northeast: { lat, lng } }` with `southwest.lat <= northeast.lat`
- `lat` in [-90, 90], `lng` in [-180, 180]; numbers may arrive as int or double. Anything else is `INVALID_ARGUMENT`.

Sorting by distance is done in Dart (`sortByDistance`); native keeps Google's order.

`language` is applied on Android by re-initializing the Places SDK with that locale when it changes. iOS has no language option and uses the device language.

`placeDetails` fails with `PLACE_ERROR` when the place has no coordinates; it never returns `0, 0`.

Native keeps at most 32 sessions and drops the oldest, so a session Dart never ends cannot leak.

`sessionToken` is a Dart-owned UUID string. Native maps it to `AutocompleteSessionToken` / `GMSAutocompleteSessionToken` and must set that token on both autocomplete and place-details requests.

Unknown methods call `result.notImplemented()` / `FlutterMethodNotImplemented`.

## Error codes

| Code | When |
|------|------|
| `INVALID_ARGUMENT` | Missing or mistyped args |
| `MISSING_API_KEY` | Host did not inject a real key in manifest / Info.plist |
| `PLACE_ERROR` | Places SDK request failed. `details` is `{ nativeCode: int }` when the SDK gave a status (Android `ApiException.statusCode`, e.g. 9011 = key rejected; iOS `NSError.code`) |
| `UNIMPLEMENTED` | Plugin not registered (Dart maps `MissingPluginException`) |
| `CANCELLED` | Android only, opt-in via `cancelPrevious`: replaced by a newer autocomplete in the same session, or the session ended |

When changing names, update Dart (`lib/src/channels/places_channels.dart`), Kotlin (`PlacesChannelConstants.kt`), Swift (`PlacesChannelConstants.swift`), this file, and run `dart run tool/check_channel_contract.dart`.
