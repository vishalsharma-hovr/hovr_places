import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channels/places_channels.dart';
import '../channels/places_payload.dart';
import '../models/place_details.dart';
import '../models/place_details_field.dart';
import '../models/place_prediction.dart';
import '../models/places_config.dart';
import '../models/places_exception.dart';
import '../models/places_geo.dart';
import '../models/places_session.dart';
import '../models/places_usage_event.dart';

/// Typed facade over the `com.hovr/places` method channel.
class HovrPlaces {
  HovrPlaces({
    MethodChannel? channel,
    HovrPlacesConfig config = const HovrPlacesConfig(),
    this.onUsage,
  }) : _channel = channel ?? const MethodChannel(PlacesChannels.name),
       _config = config;

  static HovrPlaces instance = HovrPlaces();

  final MethodChannel _channel;
  HovrPlacesConfig _config;

  /// Called after every native call (success or failure), e.g. to count
  /// billed requests per session in analytics.
  ValueChanged<PlacesUsageEvent>? onUsage;

  HovrPlacesConfig get config => _config;

  void configure(HovrPlacesConfig config) {
    _config = config;
  }

  /// Autocomplete [query] billed against [session] until [endSession] / [HovrPlacesSession.close].
  ///
  /// [origin] makes Google return [PlacePrediction.distanceMeters];
  /// [sortByDistance] then orders results nearest first. Pass at most one of
  /// [locationBias] (prefer inside) and [locationRestriction] (only inside).
  /// [types] limits results to up to 5 Google types, e.g. `['airport']`.
  ///
  /// [cancelPrevious] (Android only) cancels this session's in-flight
  /// autocomplete; the older call then fails with [PlacesErrorCodes.cancelled].
  /// Only enable it when stale results are already dropped by the caller.
  Future<List<PlacePrediction>> autocomplete({
    required String query,
    required HovrPlacesSession session,
    List<String>? countries,
    String? language,
    PlacesLatLng? origin,
    PlacesArea? locationBias,
    PlacesArea? locationRestriction,
    List<String>? types,
    String? regionCode,
    bool sortByDistance = false,
    bool cancelPrevious = false,
  }) async {
    _ensureOpen(session);
    final trimmed = _required(query, 'query');
    final region = regionCode ?? _config.regionCode;
    final effectiveCountries = countries ?? _config.countries;
    checkCountries(effectiveCountries);
    checkLocationArgs(
      origin: origin,
      locationBias: locationBias,
      locationRestriction: locationRestriction,
    );
    checkTypes(types, maxAutocompleteTypes);
    checkRegionCode(region);
    final raw = await _invoke(
      PlacesChannels.autocomplete,
      autocompleteArgs(
        query: trimmed,
        sessionToken: session.token,
        countries: effectiveCountries,
        language: language ?? _config.language,
        origin: origin,
        locationBias: locationBias,
        locationRestriction: locationRestriction,
        types: types,
        regionCode: region,
        cancelPrevious: cancelPrevious,
      ),
      session.token,
    );
    final predictions = _parse(() => parsePredictions(raw));
    return sortByDistance
        ? sortByDistancePredictions(predictions)
        : predictions;
  }

  /// Place details for [placeId], completing the [session] billing window.
  /// Extra [fields] cost more; request only what the screen needs.
  Future<PlaceDetails> fetchDetails({
    required String placeId,
    required HovrPlacesSession session,
    Set<PlaceDetailsField> fields = const <PlaceDetailsField>{},
    String? regionCode,
  }) async {
    _ensureOpen(session);
    final trimmed = _required(placeId, 'placeId');
    final region = regionCode ?? _config.regionCode;
    checkRegionCode(region);
    final raw = await _invoke(
      PlacesChannels.placeDetails,
      placeDetailsArgs(
        placeId: trimmed,
        sessionToken: session.token,
        fields: fields,
        regionCode: region,
      ),
      session.token,
    );
    return _parse(() => parsePlaceDetails(raw));
  }

  /// Places inside [area], e.g. pickup landmarks or EV chargers. Not part of
  /// an autocomplete session; each call is billed on its own.
  Future<List<PlaceDetails>> searchNearby({
    required PlacesCircle area,
    List<String>? types,
    int? maxResults,
    bool rankByDistance = false,
    Set<PlaceDetailsField> fields = const <PlaceDetailsField>{},
    String? regionCode,
  }) async {
    final region = regionCode ?? _config.regionCode;
    checkArea(area, 'area');
    checkTypes(types, 50);
    checkRegionCode(region);
    if (maxResults != null &&
        (maxResults < 1 || maxResults > maxNearbyResults)) {
      throw PlacesException(
        code: PlacesException.invalidArgument,
        message: 'maxResults must be 1–$maxNearbyResults, got $maxResults',
      );
    }
    final raw = await _invoke(
      PlacesChannels.searchNearby,
      searchNearbyArgs(
        area: area,
        types: types,
        maxResults: maxResults,
        rankByDistance: rankByDistance,
        fields: fields,
        regionCode: region,
      ),
      null,
    );
    return _parse(() => parsePlaces(raw));
  }

  /// The closest place to [point] within [radiusMeters], for "use my current
  /// location". Null when nothing is that close.
  Future<PlaceDetails?> nearestPlace(
    PlacesLatLng point, {
    double radiusMeters = 100,
    Set<PlaceDetailsField> fields = const <PlaceDetailsField>{},
  }) async {
    final places = await searchNearby(
      area: PlacesCircle(center: point, radiusMeters: radiusMeters),
      maxResults: 1,
      rankByDistance: true,
      fields: fields,
    );
    return places.isEmpty ? null : places.first;
  }

  /// Drops the native SDK session object for [session].
  Future<void> endSession(HovrPlacesSession session) async {
    if (session.isClosed) return;
    session.markClosed();
    await _invoke(
      PlacesChannels.endSession,
      endSessionArgs(sessionToken: session.token),
      session.token,
    );
  }

  /// Calls native, maps every failure to [PlacesException], reports [onUsage].
  Future<Object?> _invoke(
    String method,
    Map<String, Object> args,
    String? sessionToken,
  ) async {
    final watch = Stopwatch()..start();
    String? errorCode;
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } catch (error) {
      final mapped = PlacesException.fromPlatform(error);
      errorCode = mapped.code;
      throw mapped;
    } finally {
      onUsage?.call(
        PlacesUsageEvent(
          method: method,
          elapsed: watch.elapsed,
          sessionToken: sessionToken,
          errorCode: errorCode,
        ),
      );
    }
  }

  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } catch (error) {
      throw PlacesException.fromPlatform(error);
    }
  }

  String _required(String value, String key) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw PlacesException(
        code: PlacesException.invalidArgument,
        message: '$key must not be empty',
      );
    }
    return trimmed;
  }

  void _ensureOpen(HovrPlacesSession session) {
    if (session.isClosed) {
      throw const PlacesException(
        code: PlacesException.invalidArgument,
        message: 'session is closed',
      );
    }
  }

  @visibleForTesting
  static void debugReset({
    MethodChannel? channel,
    HovrPlacesConfig config = const HovrPlacesConfig(),
  }) {
    instance = HovrPlaces(channel: channel, config: config);
  }
}
