# Device testing

Unit tests fake the native side. Before a release, run the live checks on **one Android phone and one iPhone** with a real key. Live calls are billed (a few cents per run).

## 1. Key setup (never committed)

The key needs **Places API (New)** enabled in Google Cloud Console.

- Android: add `GOOGLE_PLACES_API_KEY=<key>` to `example/android/local.properties` (git-ignored), or export `GOOGLE_PLACES_API_KEY`.
- iOS: create `example/ios/Flutter/Secrets.xcconfig` (git-ignored) containing `GOOGLE_MAPS_API_KEY = <key>`.

Without these, the example uses `YOUR_API_KEY`, which the plugin rejects with `MISSING_API_KEY`.

## 2. Automated checks without a key

`example/integration_test/native_e2e_test.dart` drives the real Kotlin / Swift plugin over the channel: 21 bad-input cases native must reject, valid input with every option (incl. Hindi, Arabic, emoji, 1000-char queries, a date-line rectangle), session lifecycle (40 sessions over the 32 cap, idempotent endSession), `getApiKey` → `UNIMPLEMENTED`, 25 concurrent calls, and the field widget showing the missing-key error. No key and no billing:

```sh
cd example
flutter test integration_test -d <simulator-or-emulator-id>
```

## 3. Automated live checks

```sh
cd example
flutter test integration_test --dart-define=PLACES_LIVE=true -d <device-id>
```

They cover: autocomplete with `origin` (distances present and sorted), airport type filter, details with every optional field, match ranges, `nearestPlace`, Hindi and accented queries, a nonsense query returning an empty list, a Toronto restriction never returning Delhi, a made-up place id failing with a native code, and EV chargers respecting `maxResults`.

## 4. Manual checklist (run the example app)

| # | Check | Android | iOS |
|---|-------|---------|-----|
| 1 | Typing "union" shows results after ~300 ms; one letter sends nothing | ☐ | ☐ |
| 2 | Matched text is bold | ☐ | ☐ |
| 3 | Typing fast never shows results for an older query | ☐ | ☐ |
| 4 | Clear button empties field and list | ☐ | ☐ |
| 5 | Picking a result shows coordinates and address (never 0, 0) | ☐ | ☐ |
| 6 | Airport results show a plane icon | ☐ | ☐ |
| 7 | Airplane mode: an error is shown, app does not crash | ☐ | ☐ |
| 8 | Remove the key: `MISSING_API_KEY` is shown; key never appears in logs (`adb logcat` / Console.app, search `AIza`) | ☐ | ☐ |
| 9 | Android only: `language: 'fr'` returns French results | ☐ | n/a |
| 10 | With the **rider** and **driver** keys (debug and release builds), search works and no `nativeCode 9011` appears | ☐ | ☐ |
| 11 | Driver app on 0.2.0: typing fast in the neighbour destination search shows no error banner | ☐ | ☐ |

Record device model, OS version and the commit tested in the release PR.
