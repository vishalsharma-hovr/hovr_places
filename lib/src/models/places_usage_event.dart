/// One finished native Places call, for analytics and cost tracking.
/// Never contains the API key.
class PlacesUsageEvent {
  const PlacesUsageEvent({
    required this.method,
    required this.elapsed,
    this.sessionToken,
    this.errorCode,
  });

  /// Channel method, e.g. `autocomplete`, `placeDetails`, `searchNearby`.
  final String method;
  final Duration elapsed;

  /// Null for calls that are not part of a session (`searchNearby`).
  final String? sessionToken;

  /// Null when the call succeeded.
  final String? errorCode;

  bool get succeeded => errorCode == null;
}
