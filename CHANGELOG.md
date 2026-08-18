## 0.1.0

- Initial plugin: Places autocomplete, place details, and session end over `com.hovr/places`.
- Dart owns session UUIDs; native maps them to Places SDK session tokens.
- API key stays in host AndroidManifest / Info.plist (never Dart, never the channel).
