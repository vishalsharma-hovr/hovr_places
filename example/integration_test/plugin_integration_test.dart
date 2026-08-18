import 'package:flutter_test/flutter_test.dart';
import 'package:hovr_places/hovr_places.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('autocomplete without a host key returns a typed Places error', (tester) async {
    final session = HovrPlacesSession();
    try {
      await HovrPlaces.instance.autocomplete(query: 'union station', session: session);
      fail('expected PlacesException when the host key is missing');
    } on PlacesException catch (error) {
      expect(
        error.code,
        anyOf(PlacesErrorCodes.missingApiKey, PlacesErrorCodes.placeError),
      );
    } finally {
      await session.close();
    }
  });
}
