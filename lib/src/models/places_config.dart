/// Host-side Places options. The Google API key is **not** a Dart field —
/// inject it natively via AndroidManifest / Info.plist.
class HovrPlacesConfig {
  const HovrPlacesConfig({
    this.countries = const <String>['CA', 'IN'],
    this.language,
    this.debounceMs = 300,
  });

  /// ISO-3166-1 alpha-2 country codes passed to native autocomplete.
  final List<String> countries;

  /// Optional BCP-47 language code (e.g. `en`, `fr-CA`).
  final String? language;

  /// Debounce applied by [HovrPlacesAutocompleteField] only.
  final int debounceMs;
}
