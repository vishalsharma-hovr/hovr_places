# Contributing

## Setup

```bash
cd ~/Documents/hovr-packages/hovr_places
fvm flutter pub get
```

Use Flutter **3.41.9** via FVM when available. Android unit tests need JDK 17+ (HOVR uses JDK 21):

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
```

## Before opening a PR

1. Format: `dart format lib test example/lib tool`
2. Analyze: `dart analyze --fatal-warnings lib test example/lib tool`
3. Contract: `dart run tool/check_channel_contract.dart`
4. Test: `fvm flutter test`
5. Android: `cd example/android && ./gradlew :hovr_places:testDebugUnitTest`

## Channel changes

Update Dart (`lib/src/channels/places_channels.dart`), Kotlin (`PlacesChannelConstants.kt`), Swift (`PlacesChannelConstants.swift`), and `doc/CHANNEL_CONTRACT.md`. Never add a method that returns the API key.

## Secrets

Do not commit API keys, `local.properties` secrets, or `--dart-define` values. Example apps may use `YOUR_API_KEY` placeholders (treated as missing).
