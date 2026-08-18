import Flutter
import GooglePlaces
import UIKit

/// Registers the `com.hovr/places` method channel and provides the Places API key from Info.plist.
public class HovrPlacesPlugin: NSObject, FlutterPlugin {
    private static var didConfigurePlaces = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        configurePlacesIfNeeded()
        PlacesChannelHandler.register(with: registrar)
    }

    private static func configurePlacesIfNeeded() {
        guard !didConfigurePlaces else { return }
        didConfigurePlaces = true
        let trimmed = PlacesApiKey.googleMapsApiKey
        guard PlacesApiKey.isConfigured else {
            NSLog("⚠️ [hovr_places] GOOGLE_MAPS_API_KEY is missing from the host app Info.plist.")
            return
        }
        GMSPlacesClient.provideAPIKey(trimmed)
    }
}
