package com.hovr.hovr_places

/**
 * Parses Flutter method-channel maps. Never cast [Any] to [String]/[Map] without checks.
 */
internal object PlacesArgParsers {
    data class AutocompleteArgs(
        val query: String,
        val sessionToken: String,
        val countries: List<String>?,
        val language: String?,
    )

    data class PlaceDetailsArgs(
        val placeId: String,
        val sessionToken: String,
    )

    data class EndSessionArgs(
        val sessionToken: String,
    )

    sealed class ParseResult<out T> {
        data class Ok<T>(val value: T) : ParseResult<T>()
        data class Err(val message: String) : ParseResult<Nothing>()
    }

    fun parseAutocomplete(raw: Any?): ParseResult<AutocompleteArgs> {
        val map = stringKeyedMap(raw) ?: return ParseResult.Err("Expected a map of arguments")
        val query = requiredString(map, "query") ?: return ParseResult.Err("query is required")
        val sessionToken = requiredString(map, "sessionToken")
            ?: return ParseResult.Err("sessionToken is required")
        val countries = when (val parsed = optionalStringList(map, "countries")) {
            is ParseResult.Err -> return ParseResult.Err(parsed.message)
            is ParseResult.Ok -> parsed.value
        }
        val language = when (val parsed = optionalString(map, "language")) {
            is ParseResult.Err -> return ParseResult.Err(parsed.message)
            is ParseResult.Ok -> parsed.value
        }
        return ParseResult.Ok(
            AutocompleteArgs(
                query = query,
                sessionToken = sessionToken,
                countries = countries,
                language = language,
            ),
        )
    }

    fun parsePlaceDetails(raw: Any?): ParseResult<PlaceDetailsArgs> {
        val map = stringKeyedMap(raw) ?: return ParseResult.Err("Expected a map of arguments")
        val placeId = requiredString(map, "placeId") ?: return ParseResult.Err("placeId is required")
        val sessionToken = requiredString(map, "sessionToken")
            ?: return ParseResult.Err("sessionToken is required")
        return ParseResult.Ok(PlaceDetailsArgs(placeId = placeId, sessionToken = sessionToken))
    }

    fun parseEndSession(raw: Any?): ParseResult<EndSessionArgs> {
        val map = stringKeyedMap(raw) ?: return ParseResult.Err("Expected a map of arguments")
        val sessionToken = requiredString(map, "sessionToken")
            ?: return ParseResult.Err("sessionToken is required")
        return ParseResult.Ok(EndSessionArgs(sessionToken = sessionToken))
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
}
