import 'package:flutter/services.dart';

import '../channels/places_channels.dart';

/// Typed failure from the Places method channel.
class PlacesException implements Exception {
  const PlacesException({
    required this.code,
    required this.message,
    this.details,
  });

  factory PlacesException.fromPlatform(Object error) {
    if (error is PlacesException) return error;
    if (error is MissingPluginException) {
      return const PlacesException(
        code: PlacesErrorCodes.unimplemented,
        message: 'hovr_places is not available on this platform',
      );
    }
    if (error is PlatformException) {
      return PlacesException(
        code: error.code,
        message: error.message ?? error.code,
        details: error.details,
      );
    }
    return const PlacesException(
      code: PlacesErrorCodes.placeError,
      message: 'Places request failed',
    );
  }

  static const invalidArgument = PlacesErrorCodes.invalidArgument;
  static const missingApiKey = PlacesErrorCodes.missingApiKey;
  static const placeError = PlacesErrorCodes.placeError;
  static const unimplemented = PlacesErrorCodes.unimplemented;
  static const cancelled = PlacesErrorCodes.cancelled;

  final String code;
  final String message;
  final Object? details;

  /// Google's native status code for [placeError], when native sent one:
  /// Android `ApiException.statusCode` (e.g. 9011 = key rejected by the
  /// Places SDK), iOS `NSError.code`. Use it for logging and support, not UI.
  int? get nativeCode => switch (details) {
    {'nativeCode': final int code} => code,
    _ => null,
  };

  @override
  String toString() => 'PlacesException($code: $message)';
}
