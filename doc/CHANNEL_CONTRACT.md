# Channel contract

Channel name: `com.hovr/places`

There is **no** `get-api-key` method. Native code reads `com.google.android.geo.API_KEY` (Android) or `GOOGLE_MAPS_API_KEY` (iOS). The key never crosses the channel and must never be logged.

## Methods

| Method | Args | Result |
|--------|------|--------|
| `autocomplete` | `{ query, sessionToken, countries?, language? }` | `{ predictions: [{ placeId, primaryText, secondaryText, fullText }] }` |
| `placeDetails` | `{ placeId, sessionToken }` | `{ placeId, lat, lng, formattedAddress, types }` |
| `endSession` | `{ sessionToken }` | `null` |

`sessionToken` is a Dart-owned UUID string. Native maps it to `AutocompleteSessionToken` / `GMSAutocompleteSessionToken` and must set that token on both autocomplete and place-details requests.

Unknown methods call `result.notImplemented()` / `FlutterMethodNotImplemented`.

## Error codes

| Code | When |
|------|------|
| `INVALID_ARGUMENT` | Missing or mistyped args |
| `MISSING_API_KEY` | Host did not inject a real key in manifest / Info.plist |
| `PLACE_ERROR` | Places SDK request failed |
| `UNIMPLEMENTED` | Plugin not registered (Dart maps `MissingPluginException`) |

When changing names, update Dart (`lib/src/channels/places_channels.dart`), Kotlin (`PlacesChannelConstants.kt`), Swift (`PlacesChannelConstants.swift`), this file, and run `dart run tool/check_channel_contract.dart`.
