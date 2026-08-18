import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/hovr_places.dart';
import '../models/place_prediction.dart';
import '../models/places_config.dart';
import '../models/places_exception.dart';
import '../models/places_session.dart';

/// Text field that queries Places autocomplete. No trip/pickup types.
class HovrPlacesAutocompleteField extends StatefulWidget {
  const HovrPlacesAutocompleteField({
    super.key,
    this.onSelected,
    this.hintText = 'Search places',
    this.config,
    this.session,
  });

  final ValueChanged<PlacePrediction>? onSelected;
  final String hintText;
  final HovrPlacesConfig? config;
  final HovrPlacesSession? session;

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
  bool _ownsSession = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _ownsSession = widget.session == null;
    _session = widget.session ?? HovrPlacesSession();
    final config = widget.config;
    if (config != null) {
      HovrPlaces.instance.configure(config);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    if (_ownsSession) {
      unawaited(_session.close());
    }
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final ms =
        widget.config?.debounceMs ?? HovrPlaces.instance.config.debounceMs;
    _debounce = Timer(
      Duration(milliseconds: ms),
      () => unawaited(_search(value)),
    );
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hits = const <PlacePrediction>[];
        _error = null;
      });
      return;
    }
    try {
      final hits = await HovrPlaces.instance.autocomplete(
        query: query,
        session: _session,
      );
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _error = null;
      });
    } on PlacesException catch (error) {
      if (!mounted) return;
      setState(() {
        _hits = const <PlacePrediction>[];
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: widget.hintText),
          onChanged: _onChanged,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final hit in _hits)
          ListTile(
            title: Text(hit.primaryText),
            subtitle: hit.secondaryText.isEmpty
                ? null
                : Text(hit.secondaryText),
            onTap: () => widget.onSelected?.call(hit),
          ),
      ],
    );
  }
}
