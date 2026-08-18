import 'dart:math';

import '../controller/hovr_places.dart';

/// Dart-owned Places session. Native maps [token] to an SDK session object.
class HovrPlacesSession {
  HovrPlacesSession({String? token})
    : token = token ?? generatePlacesSessionToken();

  final String token;
  bool _closed = false;

  bool get isClosed => _closed;

  /// Drops the native SDK session object. Safe to call more than once.
  Future<void> close() => HovrPlaces.instance.endSession(this);

  void markClosed() {
    _closed = true;
  }
}

String generatePlacesSessionToken() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
