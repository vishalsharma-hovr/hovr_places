package com.hovr.hovr_places

import android.text.style.CharacterStyle
import android.text.style.StyleSpan
import com.google.android.gms.maps.model.LatLng
import com.google.android.libraries.places.api.model.AutocompletePrediction
import com.google.android.libraries.places.api.model.Place

/** Converts Places SDK objects into the maps described in CHANNEL_CONTRACT.md. */
internal object PlacesResultMaps {
    /** Fields every details / nearby call fetches. */
    val BASE_FIELDS = listOf(
        Place.Field.ID,
        Place.Field.LOCATION,
        Place.Field.FORMATTED_ADDRESS,
        Place.Field.TYPES,
    )

    /** [BASE_FIELDS] plus the optional channel field names Dart asked for. */
    fun placeFields(requested: List<String>): List<Place.Field> =
        BASE_FIELDS + requested.mapNotNull {
            when (it) {
                "name" -> Place.Field.DISPLAY_NAME
                "addressComponents" -> Place.Field.ADDRESS_COMPONENTS
                "viewport" -> Place.Field.VIEWPORT
                "plusCode" -> Place.Field.PLUS_CODE
                else -> null
            }
        }

    /** Null when the place has no coordinates: a (0, 0) pickup must never reach Dart. */
    fun placeDetailsMap(place: Place, requestedPlaceId: String): Map<String, Any?>? {
        val location = place.location ?: return null
        return mapOf(
            "placeId" to (place.id ?: requestedPlaceId),
            "lat" to location.latitude,
            "lng" to location.longitude,
            "formattedAddress" to (place.formattedAddress ?: ""),
            "types" to (place.placeTypes ?: emptyList()),
            "name" to place.displayName,
            "addressComponents" to place.addressComponents?.asList()?.map {
                mapOf("name" to it.name, "shortName" to it.shortName, "types" to it.types)
            },
            "viewport" to place.viewport?.let {
                mapOf("southwest" to latLngMap(it.southwest), "northeast" to latLngMap(it.northeast))
            },
            "plusCode" to place.plusCode?.let {
                mapOf("globalCode" to it.globalCode, "compoundCode" to it.compoundCode)
            },
        )
    }

    fun predictionMap(prediction: AutocompletePrediction): Map<String, Any?> = mapOf(
        "placeId" to prediction.placeId,
        "primaryText" to prediction.getPrimaryText(null).toString(),
        "secondaryText" to prediction.getSecondaryText(null).toString(),
        "fullText" to prediction.getFullText(null).toString(),
        "distanceMeters" to prediction.distanceMeters,
        "types" to prediction.types,
        "primaryMatches" to primaryMatches(prediction),
    )

    /** `[offset, length]` of each matched range; the SDK marks them with spans. */
    private fun primaryMatches(prediction: AutocompletePrediction): List<List<Int>> {
        val text = prediction.getPrimaryText(StyleSpan(android.graphics.Typeface.BOLD))
        return text.getSpans(0, text.length, CharacterStyle::class.java)
            .map { span -> listOf(text.getSpanStart(span), text.getSpanEnd(span) - text.getSpanStart(span)) }
            .filter { (_, length) -> length > 0 }
            .sortedBy { it[0] }
    }

    private fun latLngMap(point: LatLng) = mapOf("lat" to point.latitude, "lng" to point.longitude)
}
