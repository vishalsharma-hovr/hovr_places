import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hovr_places/hovr_places.dart';

void main() {
  runApp(const HovrPlacesExampleApp());
}

class HovrPlacesExampleApp extends StatelessWidget {
  const HovrPlacesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('hovr_places example')),
        body: const Padding(padding: EdgeInsets.all(16), child: _PlacesDemo()),
      ),
    );
  }
}

class _PlacesDemo extends StatefulWidget {
  const _PlacesDemo();

  @override
  State<_PlacesDemo> createState() => _PlacesDemoState();
}

class _PlacesDemoState extends State<_PlacesDemo> {
  final HovrPlacesSession _session = HovrPlacesSession();
  PlaceDetails? _details;
  String? _status;

  @override
  void initState() {
    super.initState();
    HovrPlaces.instance.configure(
      const HovrPlacesConfig(countries: ['CA', 'IN'], debounceMs: 300),
    );
  }

  @override
  void dispose() {
    unawaited(_session.close());
    super.dispose();
  }

  Future<void> _onSelected(PlacePrediction hit) async {
    setState(() => _status = 'Loading details…');
    try {
      final details = await HovrPlaces.instance.fetchDetails(
        placeId: hit.placeId,
        session: _session,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _status = null;
      });
    } on PlacesException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = '${error.code}: ${error.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'Add a Google Places key to AndroidManifest / Info.plist. '
          'The key never crosses Dart.',
        ),
        const SizedBox(height: 16),
        HovrPlacesAutocompleteField(session: _session, onSelected: _onSelected),
        if (_status != null) ...[const SizedBox(height: 16), Text(_status!)],
        if (_details != null) ...[
          const SizedBox(height: 16),
          Text(_details!.formattedAddress),
          Text('${_details!.latitude}, ${_details!.longitude}'),
        ],
      ],
    );
  }
}
