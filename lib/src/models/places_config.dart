/// Host-side Places options. The Google API key is **not** a Dart field —
/// inject it natively via AndroidManifest / Info.plist.
class HovrPlacesConfig {
  const HovrPlacesConfig({
    this.countries = const <String>[],
    this.language,
    this.debounceMs = 300,
    this.minQueryLength = 2,
    this.regionCode,
  });

  /// ISO-3166-1 alpha-2 country codes passed to native autocomplete.
  /// Empty means no country filter.
  final List<String> countries;

  /// Optional BCP-47 language code (e.g. `en`, `fr-CA`). Android only: iOS
  /// always uses the device language. On Android a new value re-initializes
  /// the Places SDK for the whole app.
  final String? language;

  /// Debounce applied by [HovrPlacesAutocompleteField] only.
  final int debounceMs;

  /// Shorter queries are not sent by [HovrPlacesAutocompleteField], so a
  /// single keystroke is never a billed request.
  final int minQueryLength;

  /// Optional 2-letter CLDR region (e.g. `CA`, `IN`) for address formatting
  /// and ranking. Unlike [language], this works per request on both platforms.
  final String? regionCode;
}
