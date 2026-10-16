import CoreLocation
import Foundation
import GooglePlaces

/// Converts Places SDK objects into the maps described in CHANNEL_CONTRACT.md.
enum PlacesResultMaps {
    /// Base properties plus the optional channel field names Dart asked for.
    static func placeProperties(_ requested: [String]) -> [String] {
        var properties: [GMSPlaceProperty] = [.placeID, .coordinate, .formattedAddress, .types]
        for field in requested {
            switch field {
            case "name": properties.append(.name)
            case "addressComponents": properties.append(.addressComponents)
            case "viewport": properties.append(.viewport)
            case "plusCode": properties.append(.plusCode)
            default: break
            }
        }
        return properties.map(\.rawValue)
    }

    /// Nil when the coordinate is invalid (-180, -180): it must never become a pickup.
    static func placeDetails(_ place: GMSPlace, requestedPlaceId: String) -> [String: Any]? {
        guard CLLocationCoordinate2DIsValid(place.coordinate) else { return nil }
        var map: [String: Any] = [
            "placeId": place.placeID ?? requestedPlaceId,
            "lat": place.coordinate.latitude,
            "lng": place.coordinate.longitude,
            "formattedAddress": place.formattedAddress ?? "",
            "types": place.types ?? [],
        ]
        if let name = place.name { map["name"] = name }
        if let components = place.addressComponents {
            map["addressComponents"] = components.map {
                ["name": $0.name, "shortName": $0.shortName ?? "", "types": $0.types]
            }
        }
        if let viewport = place.viewportInfo, viewport.isValid {
            map["viewport"] = [
                "southwest": latLng(viewport.southWest),
                "northeast": latLng(viewport.northEast),
            ]
        }
        if let plusCode = place.plusCode {
            map["plusCode"] = ["globalCode": plusCode.globalCode, "compoundCode": plusCode.compoundCode ?? ""]
        }
        return map
    }

    static func prediction(_ prediction: GMSAutocompletePlaceSuggestion) -> [String: Any] {
        [
            "placeId": prediction.placeID,
            "primaryText": prediction.attributedPrimaryText.string,
            "secondaryText": prediction.attributedSecondaryText?.string ?? "",
            "fullText": prediction.attributedFullText.string,
            "distanceMeters": prediction.distanceMeters ?? NSNull(),
            "types": prediction.types,
            "primaryMatches": matches(prediction.attributedPrimaryText),
        ]
    }

    /// `[offset, length]` of each range the SDK marks as matching the query.
    /// NSRange is in UTF-16 units, the same as Dart string offsets.
    private static func matches(_ text: NSAttributedString) -> [[Int]] {
        var out: [[Int]] = []
        text.enumerateAttribute(
            .gmsAutocompleteMatchAttribute,
            in: NSRange(location: 0, length: text.length)
        ) { value, range, _ in
            if value != nil && range.length > 0 { out.append([range.location, range.length]) }
        }
        return out
    }

    private static func latLng(_ point: CLLocationCoordinate2D) -> [String: Double] {
        ["lat": point.latitude, "lng": point.longitude]
    }
}
