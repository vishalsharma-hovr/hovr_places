# hovr_places_example

Minimal host app for `hovr_places`.

Replace `YOUR_API_KEY` in:

- `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`)
- `ios/Runner/Info.plist` (`GOOGLE_MAPS_API_KEY`)

The key stays native. Dart never receives it. With the placeholder, the UI shows `MISSING_API_KEY`.
