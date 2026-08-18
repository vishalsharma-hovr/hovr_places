import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channels/places_channels.dart';
import '../channels/places_payload.dart';
import '../models/place_details.dart';
import '../models/place_prediction.dart';
import '../models/places_config.dart';
import '../models/places_exception.dart';
import '../models/places_session.dart';

/// Typed facade over the `com.hovr/places` method channel.
class HovrPlaces {
  HovrPlaces({
    MethodChannel? channel,
    HovrPlacesConfig config = const HovrPlacesConfig(),
  }) : _channel = channel ?? const MethodChannel(PlacesChannels.name),
       _config = config;

  static HovrPlaces instance = HovrPlaces();

  final MethodChannel _channel;
  HovrPlacesConfig _config;

  HovrPlacesConfig get config => _config;

  void configure(HovrPlacesConfig config) {
    _config = config;
  }

  /// Autocomplete [query] billed against [session] until [endSession] / [HovrPlacesSession.close].
  Future<List<PlacePrediction>> autocomplete({
    required String query,
    required HovrPlacesSession session,
    List<String>? countries,
    String? language,
  }) async {
    _ensureOpen(session);
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const PlacesException(
        code: PlacesException.invalidArgument,
        message: 'query must not be empty',
      );
    }
    try {
      final raw = await _channel.invokeMethod<Object?>(
        PlacesChannels.autocomplete,
        autocompleteArgs(
          query: trimmed,
          sessionToken: session.token,
          countries: countries ?? _config.countries,
          language: language ?? _config.language,
        ),
      );
      return parsePredictions(raw);
    } catch (error) {
      throw PlacesException.fromPlatform(error);
    }
  }

  /// Place details for [placeId], completing the [session] billing window.
  Future<PlaceDetails> fetchDetails({
    required String placeId,
    required HovrPlacesSession session,
  }) async {
    _ensureOpen(session);
    final trimmed = placeId.trim();
    if (trimmed.isEmpty) {
      throw const PlacesException(
        code: PlacesException.invalidArgument,
        message: 'placeId must not be empty',
      );
    }
    try {
      final raw = await _channel.invokeMethod<Object?>(
        PlacesChannels.placeDetails,
        placeDetailsArgs(placeId: trimmed, sessionToken: session.token),
      );
      return parsePlaceDetails(raw);
    } catch (error) {
      throw PlacesException.fromPlatform(error);
    }
  }

  /// Drops the native SDK session object for [session].
  Future<void> endSession(HovrPlacesSession session) async {
    if (session.isClosed) return;
    session.markClosed();
    try {
      await _channel.invokeMethod<void>(
        PlacesChannels.endSession,
        endSessionArgs(sessionToken: session.token),
      );
    } catch (error) {
      throw PlacesException.fromPlatform(error);
    }
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
