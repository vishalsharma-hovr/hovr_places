import Flutter
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
            handleAutocomplete(call: call, result: result)
        case PlacesChannelConstants.methodPlaceDetails:
            handlePlaceDetails(call: call, result: result)
        case PlacesChannelConstants.methodEndSession:
            handleEndSession(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleAutocomplete(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch PlacesArgParsers.parseAutocomplete(call.arguments) {
        case .err(let message):
            result(FlutterError(code: PlacesChannelConstants.errorInvalidArgument, message: message, details: nil))
        case .ok(let args):
            guard PlacesApiKey.isConfigured else {
                result(missingApiKeyError())
                return
            }
            let token = sessions.token(for: args.sessionToken)
            let filter = GMSAutocompleteFilter()
            if let countries = args.countries, !countries.isEmpty {
                filter.countries = countries
            }
            let request = GMSAutocompleteRequest(query: args.query)
            request.filter = filter
            request.sessionToken = token
            GMSPlacesClient.shared().fetchAutocompleteSuggestions(from: request) { suggestions, error in
                if let error {
                    result(FlutterError(
                        code: PlacesChannelConstants.errorPlaceError,
                        message: PlacesChannelHandler.safeErrorMessage(error),
                        details: nil
                    ))
                    return
                }
                let predictions: [[String: Any]] = (suggestions ?? []).compactMap { suggestion in
                    guard let prediction = suggestion.placeSuggestion else { return nil }
                    return [
                        "placeId": prediction.placeID,
                        "primaryText": prediction.attributedPrimaryText.string,
                        "secondaryText": prediction.attributedSecondaryText?.string ?? "",
                        "fullText": prediction.attributedFullText.string,
                    ]
                }
                result(["predictions": predictions])
            }
        }
    }

    private func handlePlaceDetails(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch PlacesArgParsers.parsePlaceDetails(call.arguments) {
        case .err(let message):
            result(FlutterError(code: PlacesChannelConstants.errorInvalidArgument, message: message, details: nil))
        case .ok(let args):
            guard PlacesApiKey.isConfigured else {
                result(missingApiKeyError())
                return
            }
            let token = sessions.token(for: args.sessionToken)
            let fields: GMSPlaceField = [.placeID, .coordinate, .formattedAddress, .types]
            GMSPlacesClient.shared().fetchPlace(
                fromPlaceID: args.placeId,
                placeFields: fields,
                sessionToken: token
            ) { place, error in
                if let error {
                    result(FlutterError(
                        code: PlacesChannelConstants.errorPlaceError,
                        message: PlacesChannelHandler.safeErrorMessage(error),
                        details: nil
                    ))
                    return
                }
                guard let place else {
                    result(FlutterError(
                        code: PlacesChannelConstants.errorPlaceError,
                        message: "Place not found",
                        details: nil
                    ))
                    return
                }
                result([
                    "placeId": place.placeID ?? args.placeId,
                    "lat": place.coordinate.latitude,
                    "lng": place.coordinate.longitude,
                    "formattedAddress": place.formattedAddress ?? "",
                    "types": place.types ?? [],
                ])
            }
        }
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
