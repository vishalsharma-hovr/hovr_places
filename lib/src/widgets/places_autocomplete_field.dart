import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/hovr_places.dart';
import '../models/place_prediction.dart';
import '../models/places_config.dart';
import '../models/places_exception.dart';
import '../models/places_geo.dart';
import '../models/places_session.dart';

/// Text field that queries Places autocomplete. No trip/pickup types.
class HovrPlacesAutocompleteField extends StatefulWidget {
  const HovrPlacesAutocompleteField({
    super.key,
    this.onSelected,
    this.hintText = 'Search places',
    this.noResultsText = 'No places found',
    this.config,
    this.session,
    this.itemBuilder,
    this.origin,
    this.locationBias,
    this.locationRestriction,
    this.sortByDistance = false,
    this.types,
    this.idleBuilder,
  });

  final ValueChanged<PlacePrediction>? onSelected;
  final String hintText;
  final String noResultsText;

  /// Options for this field only. Does not change [HovrPlaces.instance].
  final HovrPlacesConfig? config;
  final HovrPlacesSession? session;

  /// Builds one result row. Defaults to a [ListTile]; call `onTap` to select.
  final Widget Function(
    BuildContext context,
    PlacePrediction prediction,
    VoidCallback onTap,
  )?
  itemBuilder;

  /// Rider/driver position. Read at search time, so pass the latest value.
  /// Enables distance labels and [sortByDistance].
  final PlacesLatLng? origin;
  final PlacesArea? locationBias;
  final PlacesArea? locationRestriction;
  final bool sortByDistance;

  /// Up to 5 Google types, e.g. `['airport']` or `['street_address']`.
  final List<String>? types;

  /// Shown while the query is shorter than `minQueryLength`, e.g. the app's
  /// Home / Work / recent places. The package does not store those.
  final WidgetBuilder? idleBuilder;

  @override
  State<HovrPlacesAutocompleteField> createState() =>
      _HovrPlacesAutocompleteFieldState();
}

class _HovrPlacesAutocompleteFieldState
    extends State<HovrPlacesAutocompleteField> {
  late final TextEditingController _controller;
  late final HovrPlacesSession _session;
  Timer? _debounce;
  List<PlacePrediction> _hits = const <PlacePrediction>[];
  String? _error;
  bool _loading = false;
  bool _searched = false;
  bool _ownsSession = false;
  // Bumped on every keystroke; a response for an older value is dropped.
  int _requestId = 0;

  HovrPlacesConfig get _config => widget.config ?? HovrPlaces.instance.config;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _ownsSession = widget.session == null;
    _session = widget.session ?? HovrPlacesSession();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    if (_ownsSession) {
      // Nothing can be done with a failed endSession while tearing down.
      unawaited(_session.close().catchError((Object _) {}));
    }
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final id = ++_requestId;
    setState(() {}); // Refresh the clear button.
    _debounce = Timer(
      Duration(milliseconds: _config.debounceMs),
      () => unawaited(_search(value, id)),
    );
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  Future<void> _search(String value, int id) async {
    final query = value.trim();
    if (query.length < _config.minQueryLength) {
      _show(id, const <PlacePrediction>[], null, searched: false);
      return;
    }
    setState(() => _loading = true);
    try {
      final hits = await HovrPlaces.instance.autocomplete(
        query: query,
        session: _session,
        countries: widget.config?.countries,
        language: widget.config?.language,
        regionCode: widget.config?.regionCode,
        types: widget.types,
        origin: widget.origin,
        locationBias: widget.locationBias,
        locationRestriction: widget.locationRestriction,
        sortByDistance: widget.sortByDistance,
        cancelPrevious: true, // Stale responses are dropped by _requestId.
      );
      _show(id, hits, null, searched: true);
    } on PlacesException catch (error) {
      _show(id, const <PlacePrediction>[], error.message, searched: true);
    }
  }

  void _show(
    int id,
    List<PlacePrediction> hits,
    String? error, {
    required bool searched,
  }) {
    if (!mounted || id != _requestId) return;
    setState(() {
      _hits = hits;
      _error = error;
      _searched = searched;
      _loading = false;
    });
  }

  Widget _row(BuildContext context, PlacePrediction hit) {
    void onTap() => widget.onSelected?.call(hit);
    final builder = widget.itemBuilder;
    if (builder != null) return builder(context, hit, onTap);
    final distance = hit.distanceMeters;
    return ListTile(
      leading: hit.isAirport ? const Icon(Icons.flight) : null,
      title: Text.rich(highlightMatches(hit.primaryText, hit.primaryMatches)),
      subtitle: hit.secondaryText.isEmpty ? null : Text(hit.secondaryText),
      trailing: distance == null ? null : Text(formatDistanceMeters(distance)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final noResults = _searched && !_loading && _error == null && _hits.isEmpty;
    final idle = widget.idleBuilder;
    final showIdle =
        idle != null && _controller.text.trim().length < _config.minQueryLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear',
                    onPressed: _clear,
                  ),
          ),
          onChanged: _onChanged,
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (noResults)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(widget.noResultsText),
          ),
        if (showIdle) idle(context),
        for (final hit in _hits) _row(context, hit),
      ],
    );
  }
}

/// "850 m" under 1 km, otherwise "1.2 km".
String formatDistanceMeters(int meters) {
  if (meters < 1000) return '$meters m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// [text] with each `(offset, length)` range in bold.
TextSpan highlightMatches(String text, List<(int, int)> matches) {
  final sorted = [...matches]..sort((a, b) => a.$1.compareTo(b.$1));
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final (offset, length) in sorted) {
    if (offset < cursor) continue; // Overlapping range.
    if (offset > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, offset)));
    }
    spans.add(
      TextSpan(
        text: text.substring(offset, offset + length),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    cursor = offset + length;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return TextSpan(children: spans);
}
