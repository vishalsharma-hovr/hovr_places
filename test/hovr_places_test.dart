import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';
import 'package:hovr_places/src/channels/places_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(PlacesChannels.name);

  setUp(() {
    HovrPlaces.debugReset(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    HovrPlaces.debugReset();
  });

  group('payload encoding', () {
    test('autocompleteArgs includes optional filters', () {
      expect(
        autocompleteArgs(
          query: 'union station',
          sessionToken: 'tok',
          countries: const <String>['CA'],
          language: 'en',
        ),
        <String, Object>{
          'query': 'union station',
          'sessionToken': 'tok',
          'countries': <String>['CA'],
          'language': 'en',
        },
      );
    });

    test('placeDetailsArgs encodes ids', () {
      expect(
        placeDetailsArgs(placeId: 'ChIJd', sessionToken: 'tok'),
        <String, Object>{'placeId': 'ChIJd', 'sessionToken': 'tok'},
      );
    });
  });

  group('models', () {
    test('PlacePrediction.fromMap accepts place_id alias', () {
      final hit = PlacePrediction.fromMap(<String, Object?>{
        'place_id': 'abc',
        'primaryText': 'Union Station',
        'secondaryText': 'Toronto',
        'fullText': 'Union Station, Toronto',
      });
      expect(hit.placeId, 'abc');
      expect(hit.primaryText, 'Union Station');
    });

    test('PlaceDetails.fromMap accepts numeric and string coords', () {
      final place = PlaceDetails.fromMap(<String, Object?>{
        'placeId': 'abc',
        'lat': '43.65',
        'lng': -79.38,
        'formattedAddress': 'Toronto',
        'types': <Object>['transit_station'],
      });
      expect(place.latitude, 43.65);
      expect(place.longitude, -79.38);
      expect(place.types, <String>['transit_station']);
    });

    test('session token looks like UUID v4', () {
      final token = generatePlacesSessionToken();
      expect(token.length, 36);
      expect(token[14], '4');
    });
  });

  group('HovrPlaces channel', () {
    test('autocomplete maps predictions', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, PlacesChannels.autocomplete);
            final args = asStringKeyedMap(call.arguments, 'autocomplete args');
            expect(args['query'], 'union station');
            expect(args['sessionToken'], isNotEmpty);
            return <String, Object>{
              'predictions': <Map<String, Object>>[
                <String, Object>{
                  'placeId': 'p1',
                  'primaryText': 'Union Station',
                  'secondaryText': 'Toronto',
                  'fullText': 'Union Station, Toronto',
                },
              ],
            };
          });

      final session = HovrPlacesSession(token: 'sess-1');
      final hits = await HovrPlaces.instance.autocomplete(
        query: 'union station',
        session: session,
      );
      expect(hits, hasLength(1));
      expect(hits.single.placeId, 'p1');
    });

    test('fetchDetails maps lat lng', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            expect(call.method, PlacesChannels.placeDetails);
            return <String, Object>{
              'placeId': 'p1',
              'lat': 43.65,
              'lng': -79.38,
              'formattedAddress': 'Toronto',
              'types': <String>['point_of_interest'],
            };
          });

      final session = HovrPlacesSession(token: 'sess-1');
      final place = await HovrPlaces.instance.fetchDetails(
        placeId: 'p1',
        session: session,
      );
      expect(place.latitude, 43.65);
      expect(place.formattedAddress, 'Toronto');
    });

    test('endSession is invoked from session.close', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call.method);
            return null;
          });

      final session = HovrPlacesSession(token: 'sess-1');
      await session.close();
      expect(calls, <String>[PlacesChannels.endSession]);
      expect(session.isClosed, isTrue);
    });

    test('empty query throws INVALID_ARGUMENT', () async {
      expect(
        () => HovrPlaces.instance.autocomplete(
          query: '  ',
          session: HovrPlacesSession(token: 'sess-1'),
        ),
        throwsA(
          isA<PlacesException>().having(
            (e) => e.code,
            'code',
            PlacesErrorCodes.invalidArgument,
          ),
        ),
      );
    });

    test('MISSING_API_KEY is mapped from PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            throw PlatformException(
              code: PlacesErrorCodes.missingApiKey,
              message:
                  'Google Places API key is missing from the host AndroidManifest',
            );
          });

      expect(
        () => HovrPlaces.instance.autocomplete(
          query: 'union',
          session: HovrPlacesSession(token: 'sess-1'),
        ),
        throwsA(
          isA<PlacesException>().having(
            (e) => e.code,
            'code',
            PlacesErrorCodes.missingApiKey,
          ),
        ),
      );
    });
  });
}
