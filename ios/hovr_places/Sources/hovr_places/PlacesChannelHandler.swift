import Flutter
import CoreLocation
import Foundation
import GooglePlaces

final class PlacesChannelHandler: NSObject, FlutterPlugin {
    private let sessions = PlacesSessionStore()

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: PlacesChannelConstants.channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = PlacesChannelHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case PlacesChannelConstants.methodAutocomplete:
            withArgs(PlacesArgParsers.parseAutocomplete(call.arguments), result) {
                self.handleAutocomplete($0, result: result)
            }
        case PlacesChannelConstants.methodPlaceDetails:
            withArgs(PlacesArgParsers.parsePlaceDetails(call.arguments), result) {
                self.handlePlaceDetails($0, result: result)
            }
        case PlacesChannelConstants.methodSearchNearby:
            withArgs(PlacesArgParsers.parseSearchNearby(call.arguments), result) {
                self.handleSearchNearby($0, result: result)
            }
        case PlacesChannelConstants.methodEndSession:
            handleEndSession(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Replies INVALID_ARGUMENT or MISSING_API_KEY, otherwise runs [handle].
    private func withArgs<T>(
        _ parsed: PlacesArgParsers.ParseResult<T>,
        _ result: @escaping FlutterResult,
        handle: (T) -> Void
    ) {
        switch parsed {
        case .err(let message):
            result(FlutterError(code: PlacesChannelConstants.errorInvalidArgument, message: message, details: nil))
        case .ok(let args):
            guard PlacesApiKey.isConfigured else {
                result(missingApiKeyError())
                return
            }
            handle(args)
        }
    }

    /// iOS has no request cancellation; Dart drops stale responses instead.
    private func handleAutocomplete(_ args: PlacesArgParsers.AutocompleteArgs, result: @escaping FlutterResult) {
        let filter = GMSAutocompleteFilter()
        if let countries = args.countries, !countries.isEmpty {
            filter.countries = countries
        }
        if let origin = args.origin {
            filter.origin = CLLocation(latitude: origin.lat, longitude: origin.lng)
        }
        if let bias = args.locationBias {
            filter.locationBias = PlacesChannelHandler.locationOption(bias)
        }
        if let restriction = args.locationRestriction {
            filter.locationRestriction = PlacesChannelHandler.locationOption(restriction)
        }
        filter.types = args.types
        filter.regionCode = args.regionCode
        let request = GMSAutocompleteRequest(query: args.query)
        request.filter = filter
        request.sessionToken = sessions.token(for: args.sessionToken)
        GMSPlacesClient.shared().fetchAutocompleteSuggestions(from: request) { suggestions, error in
            if let error {
                result(PlacesChannelHandler.placeError(error))
                return
            }
            let predictions = (suggestions ?? []).compactMap(\.placeSuggestion).map(PlacesResultMaps.prediction)
            result(["predictions": predictions])
        }
    }

    /// regionCode is Android-only for details: GMSFetchPlaceRequest has no such option.
    private func handlePlaceDetails(_ args: PlacesArgParsers.PlaceDetailsArgs, result: @escaping FlutterResult) {
        let request = GMSFetchPlaceRequest(
            placeID: args.placeId,
            placeProperties: PlacesResultMaps.placeProperties(args.fields),
            sessionToken: sessions.token(for: args.sessionToken)
        )
        GMSPlacesClient.shared().fetchPlace(with: request) { place, error in
            if let error {
                result(PlacesChannelHandler.placeError(error))
                return
            }
            guard let place else {
                result(FlutterError(code: PlacesChannelConstants.errorPlaceError, message: "Place not found", details: nil))
                return
            }
            guard let details = PlacesResultMaps.placeDetails(place, requestedPlaceId: args.placeId) else {
                result(FlutterError(
                    code: PlacesChannelConstants.errorPlaceError,
                    message: "Place has no coordinates",
                    details: nil
                ))
                return
            }
            result(details)
        }
    }

    private func handleSearchNearby(_ args: PlacesArgParsers.SearchNearbyArgs, result: @escaping FlutterResult) {
        let center = CLLocationCoordinate2D(latitude: args.center.lat, longitude: args.center.lng)
        let request = GMSPlaceSearchNearbyRequest(
            locationRestriction: GMSPlaceCircularLocationOption(center, args.radiusMeters),
            placeProperties: PlacesResultMaps.placeProperties(args.fields)
        )
        request.includedTypes = args.types
        if let maxResults = args.maxResults { request.maxResultCount = maxResults }
        request.rankPreference = args.rankByDistance ? .distance : .popularity
        request.regionCode = args.regionCode
        // shortcut: callback API is deprecated from GooglePlaces 10.10, but the driver app pins
        // 10.1. Switch to searchNearby(with:completion:) once every host is on >= 10.10.
        GMSPlacesClient.shared().searchNearby(with: request) { places, error in
            if let error {
                result(PlacesChannelHandler.placeError(error))
                return
            }
            // Places without valid coordinates are dropped, never sent as pickups.
            let places = (places ?? []).compactMap {
                PlacesResultMaps.placeDetails($0, requestedPlaceId: $0.placeID ?? "")
            }
            result(["places": places])
        }
    }

    private static func placeError(_ error: Error) -> FlutterError {
        FlutterError(
            code: PlacesChannelConstants.errorPlaceError,
            message: safeErrorMessage(error),
            details: ["nativeCode": (error as NSError).code]
        )
    }

    private func handleEndSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch PlacesArgParsers.parseEndSession(call.arguments) {
        case .err(let message):
            result(FlutterError(code: PlacesChannelConstants.errorInvalidArgument, message: message, details: nil))
        case .ok(let args):
            sessions.endSession(args.sessionToken)
            result(nil)
        }
    }

    /// Circle and rectangle options conform to both bias and restriction.
    static func locationOption(
        _ area: PlacesArgParsers.AreaArg
    ) -> GMSPlaceLocationBias & GMSPlaceLocationRestriction {
        switch area {
        case .circle(let center, let radius):
            return GMSPlaceCircularLocationOption(coordinate(center), radius)
        case .rectangle(let southwest, let northeast):
            return GMSPlaceRectangularLocationOption(coordinate(northeast), coordinate(southwest))
        }
    }

    private static func coordinate(_ point: PlacesArgParsers.LatLngArg) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng)
    }

    private func missingApiKeyError() -> FlutterError {
        FlutterError(
            code: PlacesChannelConstants.errorMissingApiKey,
            message: "GOOGLE_MAPS_API_KEY is missing from the host Info.plist",
            details: nil
        )
    }

    static func safeErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("AIza") || message.uppercased().contains("YOUR_API_KEY") {
            return "Places SDK request failed"
        }
        return message.isEmpty ? "Places SDK request failed" : message
    }
}
