package com.hovr.hovr_places

import kotlin.math.abs

/**
 * Parses Flutter method-channel maps. Never cast [Any] to [String]/[Map] without checks.
 */
internal object PlacesArgParsers {
    data class AutocompleteArgs(
        val query: String,
        val sessionToken: String,
        val countries: List<String>?,
        val language: String?,
        val origin: LatLngArg? = null,
        val locationBias: AreaArg? = null,
        val locationRestriction: AreaArg? = null,
        val types: List<String>? = null,
        val regionCode: String? = null,
        val cancelPrevious: Boolean = false,
    )

    data class LatLngArg(val lat: Double, val lng: Double)

    sealed class AreaArg {
        data class Circle(val center: LatLngArg, val radiusMeters: Double) : AreaArg()
        data class Rectangle(val southwest: LatLngArg, val northeast: LatLngArg) : AreaArg()
    }

    data class PlaceDetailsArgs(
        val placeId: String,
        val sessionToken: String,
        val fields: List<String> = emptyList(),
        val regionCode: String? = null,
    )

    data class SearchNearbyArgs(
        val area: AreaArg.Circle,
        val types: List<String>?,
        val maxResults: Int?,
        val rankByDistance: Boolean,
        val fields: List<String>,
        val regionCode: String?,
    )

    data class EndSessionArgs(
        val sessionToken: String,
    )

    sealed class ParseResult<out T> {
        data class Ok<T>(val value: T) : ParseResult<T>()
        data class Err(val message: String) : ParseResult<Nothing>()
    }

    /** Optional place-details fields Dart may request, by channel name. */
    val DETAIL_FIELDS = setOf("name", "addressComponents", "viewport", "plusCode")

    private const val MAX_RADIUS_METERS = 50_000.0
    private const val MAX_AUTOCOMPLETE_TYPES = 5
    private const val MAX_COUNTRIES = 15
    private const val MAX_NEARBY_TYPES = 50
    private const val MAX_NEARBY_RESULTS = 20

    fun parseAutocomplete(raw: Any?): ParseResult<AutocompleteArgs> = parsing {
        val map = argsMap(raw)
        val bias = map["locationBias"]?.let { parseArea(it, "locationBias").get() }
        val restriction = map["locationRestriction"]?.let {
            parseArea(it, "locationRestriction").get()
        }
        if (bias != null && restriction != null) {
            fail("Pass locationBias or locationRestriction, not both")
        }
        AutocompleteArgs(
            query = requiredString(map, "query") ?: fail("query is required"),
            sessionToken = sessionToken(map),
            countries = countries(map),
            language = optionalString(map, "language").get(),
            origin = map["origin"]?.let { parseLatLng(it, "origin").get() },
            locationBias = bias,
            locationRestriction = restriction,
            types = types(map, MAX_AUTOCOMPLETE_TYPES),
            regionCode = regionCode(map),
            cancelPrevious = when (val value = map["cancelPrevious"]) {
                null -> false
                is Boolean -> value
                else -> fail("cancelPrevious must be a bool")
            },
        )
    }

    fun parsePlaceDetails(raw: Any?): ParseResult<PlaceDetailsArgs> = parsing {
        val map = argsMap(raw)
        PlaceDetailsArgs(
            placeId = requiredString(map, "placeId") ?: fail("placeId is required"),
            sessionToken = sessionToken(map),
            fields = detailFields(map),
            regionCode = regionCode(map),
        )
    }

    fun parseSearchNearby(raw: Any?): ParseResult<SearchNearbyArgs> = parsing {
        val map = argsMap(raw)
        val circle = mapOf(
            "type" to "circle",
            "center" to map["center"],
            "radiusMeters" to map["radiusMeters"],
        )
        val maxResults = map["maxResults"]?.let {
            (it as? Number)?.toInt()?.takeIf { n -> n in 1..MAX_NEARBY_RESULTS }
                ?: fail("maxResults must be 1–$MAX_NEARBY_RESULTS")
        }
        val rankByDistance = when (map["rankBy"]) {
            null, "popularity" -> false
            "distance" -> true
            else -> fail("rankBy must be \"distance\" or \"popularity\"")
        }
        SearchNearbyArgs(
            area = parseArea(circle, "area").get() as AreaArg.Circle,
            types = types(map, MAX_NEARBY_TYPES),
            maxResults = maxResults,
            rankByDistance = rankByDistance,
            fields = detailFields(map),
            regionCode = regionCode(map),
        )
    }

    fun parseEndSession(raw: Any?): ParseResult<EndSessionArgs> = parsing {
        EndSessionArgs(sessionToken = sessionToken(argsMap(raw)))
    }

    fun parseLatLng(raw: Any?, key: String): ParseResult<LatLngArg> = parsing {
        val map = stringKeyedMap(raw) ?: fail("$key must be a map")
        val lat = (map["lat"] as? Number)?.toDouble()
        val lng = (map["lng"] as? Number)?.toDouble()
        // !(<=) also rejects NaN.
        if (lat == null || lng == null || !(abs(lat) <= 90.0 && abs(lng) <= 180.0)) {
            fail("$key needs lat in [-90, 90] and lng in [-180, 180]")
        }
        LatLngArg(lat, lng)
    }

    fun parseArea(raw: Any?, key: String): ParseResult<AreaArg> = parsing {
        val map = stringKeyedMap(raw) ?: fail("$key must be a map")
        when (map["type"]) {
            "circle" -> {
                val center = parseLatLng(map["center"], "$key.center").get()
                val radius = (map["radiusMeters"] as? Number)?.toDouble()
                if (radius == null || !(radius > 0.0 && radius <= MAX_RADIUS_METERS)) {
                    fail("$key.radiusMeters must be in (0, 50000]")
                }
                AreaArg.Circle(center, radius)
            }
            "rectangle" -> {
                val sw = parseLatLng(map["southwest"], "$key.southwest").get()
                val ne = parseLatLng(map["northeast"], "$key.northeast").get()
                if (sw.lat > ne.lat) fail("$key.southwest must be south of $key.northeast")
                AreaArg.Rectangle(sw, ne)
            }
            else -> fail("$key.type must be \"circle\" or \"rectangle\"")
        }
    }

    fun stringKeyedMap(raw: Any?): Map<String, Any?>? {
        if (raw == null || raw !is Map<*, *>) return null
        val out = HashMap<String, Any?>(raw.size)
        for ((key, value) in raw) {
            if (key !is String) return null
            out[key] = value
        }
        return out
    }

    fun requiredString(map: Map<String, Any?>, key: String): String? {
        val value = map[key] ?: return null
        if (value !is String) return null
        val trimmed = value.trim()
        return trimmed.takeIf { it.isNotEmpty() }
    }

    fun optionalString(map: Map<String, Any?>, key: String): ParseResult<String?> {
        val value = map[key] ?: return ParseResult.Ok(null)
        if (value !is String) return ParseResult.Err("$key must be a String")
        val trimmed = value.trim()
        return ParseResult.Ok(trimmed.takeIf { it.isNotEmpty() })
    }

    fun optionalStringList(map: Map<String, Any?>, key: String): ParseResult<List<String>?> {
        val value = map[key] ?: return ParseResult.Ok(null)
        if (value !is List<*>) return ParseResult.Err("$key must be a List")
        val out = ArrayList<String>(value.size)
        for (item in value) {
            if (item !is String) return ParseResult.Err("$key must contain only Strings")
            val trimmed = item.trim()
            if (trimmed.isNotEmpty()) out.add(trimmed)
        }
        return ParseResult.Ok(out)
    }

    private fun argsMap(raw: Any?) = stringKeyedMap(raw) ?: fail("Expected a map of arguments")

    private fun sessionToken(map: Map<String, Any?>) =
        requiredString(map, "sessionToken") ?: fail("sessionToken is required")

    private fun types(map: Map<String, Any?>, max: Int): List<String>? {
        val types = optionalStringList(map, "types").get() ?: return null
        if (types.isEmpty() || types.size > max) fail("types must have 1–$max entries")
        return types
    }

    private fun countries(map: Map<String, Any?>): List<String>? {
        val countries = optionalStringList(map, "countries").get() ?: return null
        if (countries.size > MAX_COUNTRIES || countries.any { !it.matches(Regex("[A-Za-z]{2}")) }) {
            fail("countries must be up to $MAX_COUNTRIES 2-letter codes")
        }
        return countries
    }

    private fun regionCode(map: Map<String, Any?>): String? {
        val code = optionalString(map, "regionCode").get() ?: return null
        if (!code.matches(Regex("[A-Za-z]{2}"))) fail("regionCode must be 2 letters")
        return code
    }

    private fun detailFields(map: Map<String, Any?>): List<String> {
        val fields = optionalStringList(map, "fields").get() ?: return emptyList()
        val unknown = fields.filterNot { it in DETAIL_FIELDS }
        if (unknown.isNotEmpty()) fail("Unknown fields: $unknown")
        return fields
    }

    /** Lets each parser read top to bottom: [fail] stops it with an Err. */
    private class Invalid(message: String) : Exception(message)

    private fun fail(message: String): Nothing = throw Invalid(message)

    private fun <T> ParseResult<T>.get(): T = when (this) {
        is ParseResult.Ok -> value
        is ParseResult.Err -> fail(message)
    }

    private inline fun <T> parsing(block: () -> T): ParseResult<T> = try {
        ParseResult.Ok(block())
    } catch (error: Invalid) {
        ParseResult.Err(error.message.orEmpty())
    }
}
