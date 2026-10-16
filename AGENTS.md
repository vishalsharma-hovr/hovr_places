# hovr_places agent notes

- Plugin scope: Google Places autocomplete, place details and nearby search over MethodChannel `com.hovr/places`.
- Methods: `autocomplete`, `placeDetails`, `searchNearby`, `endSession`. `searchNearby` is not session-billed.
- Dart owns a UUID `sessionToken`; native maps it to SDK session objects and **must** set the token on both autocomplete and details.
- The API key is **never** a Dart field and **never** crosses the channel. No `get-api-key` method.
- Host apps inject `com.google.android.geo.API_KEY` / `GOOGLE_MAPS_API_KEY` (same as `hovr_ride_map`).
- Do **not** add trip, FindRide, neighbour, or saved-places types. No `hovr_sdk` imports.
- Errors: `INVALID_ARGUMENT`, `MISSING_API_KEY`, `PLACE_ERROR`, `UNIMPLEMENTED`, `CANCELLED` (Android only). Never log the key.
- HOVR safety: validate channel args before use, `result.notImplemented()` for unknown methods, ~60-line functions, zero analyzer warnings.
- After channel name changes: update Dart, Kotlin, Swift, `doc/CHANNEL_CONTRACT.md`, and run `dart run tool/check_channel_contract.dart`.
