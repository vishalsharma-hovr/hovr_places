package com.hovr.hovr_places

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PlacesArgParsersTest {
    @Test
    fun parseAutocomplete_readsRequiredAndOptionalFields() {
        val result = PlacesArgParsers.parseAutocomplete(
            mapOf(
                "query" to " union station ",
                "sessionToken" to "abc-123",
                "countries" to listOf("CA", "IN"),
                "language" to "en",
            ),
        )
        val args = (result as PlacesArgParsers.ParseResult.Ok).value
        assertEquals("union station", args.query)
        assertEquals("abc-123", args.sessionToken)
        assertEquals(listOf("CA", "IN"), args.countries)
        assertEquals("en", args.language)
    }

    @Test
    fun parseAutocomplete_rejectsMissingQuery() {
        val result = PlacesArgParsers.parseAutocomplete(
            mapOf("sessionToken" to "abc-123"),
        )
        assertTrue(result is PlacesArgParsers.ParseResult.Err)
    }

    @Test
    fun parseAutocomplete_rejectsNonMap() {
        val result = PlacesArgParsers.parseAutocomplete("union station")
        assertTrue(result is PlacesArgParsers.ParseResult.Err)
    }

    @Test
    fun parsePlaceDetails_readsIds() {
        val result = PlacesArgParsers.parsePlaceDetails(
            mapOf("placeId" to "ChIJd", "sessionToken" to "tok"),
        )
        val args = (result as PlacesArgParsers.ParseResult.Ok).value
        assertEquals("ChIJd", args.placeId)
        assertEquals("tok", args.sessionToken)
    }

    @Test
    fun parsePlaceDetails_rejectsBlankPlaceId() {
        val result = PlacesArgParsers.parsePlaceDetails(
            mapOf("placeId" to "  ", "sessionToken" to "tok"),
        )
        assertTrue(result is PlacesArgParsers.ParseResult.Err)
    }

    @Test
    fun parseEndSession_readsToken() {
        val result = PlacesArgParsers.parseEndSession(mapOf("sessionToken" to "tok"))
        val args = (result as PlacesArgParsers.ParseResult.Ok).value
        assertEquals("tok", args.sessionToken)
    }

    @Test
    fun requiredString_rejectsNonString() {
        assertNull(PlacesArgParsers.requiredString(mapOf("query" to 1), "query"))
    }

    @Test
    fun apiKeyValidator_rejectsPlaceholders() {
        assertEquals(false, PlacesApiKey.isValid(""))
        assertEquals(false, PlacesApiKey.isValid("YOUR_API_KEY"))
        assertEquals(false, PlacesApiKey.isValid("\$(GOOGLE_MAPS_API_KEY)"))
        assertEquals(true, PlacesApiKey.isValid("AIzaSyValidLookingKey"))
    }

    private fun autocomplete(extra: Map<String, Any?>) = PlacesArgParsers.parseAutocomplete(
        mapOf("query" to "union", "sessionToken" to "tok") + extra,
    )

    private val circle = mapOf(
        "type" to "circle",
        "center" to mapOf("lat" to 43.65, "lng" to -79.38),
        "radiusMeters" to 5000.0,
    )

    @Test
    fun parseAutocomplete_readsOriginAndCircleBias() {
        val result = autocomplete(
            mapOf("origin" to mapOf("lat" to 43.65, "lng" to -79.38), "locationBias" to circle),
        )
        val args = (result as PlacesArgParsers.ParseResult.Ok).value
        assertEquals("origin", PlacesArgParsers.LatLngArg(43.65, -79.38), args.origin)
        assertEquals(
            "circle bias",
            PlacesArgParsers.AreaArg.Circle(PlacesArgParsers.LatLngArg(43.65, -79.38), 5000.0),
            args.locationBias,
        )
    }

    @Test
    fun parseAutocomplete_readsRectangleRestrictionWithIntCoords() {
        val result = autocomplete(
            mapOf(
                "locationRestriction" to mapOf(
                    "type" to "rectangle",
                    "southwest" to mapOf("lat" to 43, "lng" to -80),
                    "northeast" to mapOf("lat" to 44, "lng" to -79),
                ),
            ),
        )
        val args = (result as PlacesArgParsers.ParseResult.Ok).value
        assertTrue(
            "Dart may send whole numbers as Int; they must still parse",
            args.locationRestriction is PlacesArgParsers.AreaArg.Rectangle,
        )
    }

    @Test
    fun parseAutocomplete_rejectsBadLocations() {
        val bad = mapOf(
            "origin out of range" to mapOf("origin" to mapOf("lat" to 95.0, "lng" to 0.0)),
            "origin NaN" to mapOf("origin" to mapOf("lat" to Double.NaN, "lng" to 0.0)),
            "radius over 50 km" to mapOf("locationBias" to circle + ("radiusMeters" to 60000.0)),
            "unknown area type" to mapOf("locationBias" to mapOf("type" to "polygon")),
            "bias and restriction together" to mapOf(
                "locationBias" to circle,
                "locationRestriction" to circle,
            ),
            "swapped rectangle corners" to mapOf(
                "locationRestriction" to mapOf(
                    "type" to "rectangle",
                    "southwest" to mapOf("lat" to 44.0, "lng" to -80.0),
                    "northeast" to mapOf("lat" to 43.0, "lng" to -79.0),
                ),
            ),
        )
        for ((why, extra) in bad) {
            assertTrue(
                "expected INVALID_ARGUMENT for: $why",
                autocomplete(extra) is PlacesArgParsers.ParseResult.Err,
            )
        }
    }

    @Test
    fun parseAutocomplete_readsTypesAndRegionCode() {
        val args = (autocomplete(mapOf("types" to listOf("airport"), "regionCode" to "IN"))
            as PlacesArgParsers.ParseResult.Ok).value
        assertEquals("types", listOf("airport"), args.types)
        assertEquals("regionCode", "IN", args.regionCode)
    }

    @Test
    fun parseAutocomplete_rejectsBadTypesAndRegion() {
        val bad = mapOf(
            "6 types" to mapOf("types" to List(6) { "airport" }),
            "empty types" to mapOf("types" to emptyList<String>()),
            "3-letter region" to mapOf("regionCode" to "IND"),
        )
        for ((why, extra) in bad) {
            assertTrue("expected INVALID_ARGUMENT for: $why", autocomplete(extra) is PlacesArgParsers.ParseResult.Err)
        }
    }

    @Test
    fun parsePlaceDetails_readsFieldsAndRejectsUnknown() {
        val ok = PlacesArgParsers.parsePlaceDetails(
            mapOf("placeId" to "p1", "sessionToken" to "tok", "fields" to listOf("name", "viewport")),
        )
        assertEquals("fields", listOf("name", "viewport"), (ok as PlacesArgParsers.ParseResult.Ok).value.fields)
        val bad = PlacesArgParsers.parsePlaceDetails(
            mapOf("placeId" to "p1", "sessionToken" to "tok", "fields" to listOf("photos")),
        )
        assertTrue("unknown field 'photos' must be rejected, not silently billed", bad is PlacesArgParsers.ParseResult.Err)
    }

    @Test
    fun parseSearchNearby_readsAllArgs() {
        val result = PlacesArgParsers.parseSearchNearby(
            mapOf(
                "center" to mapOf("lat" to 43.65, "lng" to -79.38),
                "radiusMeters" to 500,
                "types" to listOf("gas_station"),
                "maxResults" to 5,
                "rankBy" to "distance",
            ),
        )
        val args = (result as PlacesArgParsers.ParseResult.Ok).value
        assertEquals("radius", 500.0, args.area.radiusMeters, 0.0)
        assertEquals("types", listOf("gas_station"), args.types)
        assertEquals("maxResults", 5, args.maxResults)
        assertTrue("rankBy distance", args.rankByDistance)
    }

    @Test
    fun parseSearchNearby_rejectsBadArgs() {
        val valid = mapOf("center" to mapOf("lat" to 43.65, "lng" to -79.38), "radiusMeters" to 500)
        val bad = mapOf(
            "no center" to mapOf("radiusMeters" to 500),
            "radius 0" to valid + ("radiusMeters" to 0),
            "maxResults 21" to valid + ("maxResults" to 21),
            "rankBy rating" to valid + ("rankBy" to "rating"),
        )
        for ((why, args) in bad) {
            assertTrue(
                "expected INVALID_ARGUMENT for: $why",
                PlacesArgParsers.parseSearchNearby(args) is PlacesArgParsers.ParseResult.Err,
            )
        }
    }

    @Test
    fun parseAutocomplete_cancelPreviousIsOptInAndMustBeBool() {
        val off = (autocomplete(emptyMap()) as PlacesArgParsers.ParseResult.Ok).value
        assertTrue("absent cancelPrevious must mean no cancellation (0.1.x behaviour)", !off.cancelPrevious)
        val on = (autocomplete(mapOf("cancelPrevious" to true)) as PlacesArgParsers.ParseResult.Ok).value
        assertTrue("cancelPrevious true", on.cancelPrevious)
        assertTrue(
            "cancelPrevious \"yes\" must be INVALID_ARGUMENT",
            autocomplete(mapOf("cancelPrevious" to "yes")) is PlacesArgParsers.ParseResult.Err,
        )
    }

    @Test
    fun parseAutocomplete_googleDocumentedBoundaries() {
        val codes = listOf("CA", "IN", "US", "GB", "FR", "DE", "IT", "ES", "MX", "BR", "AU", "NZ", "JP", "AE", "SG", "ZA")
        val accepted = mapOf(
            "15 countries" to mapOf("countries" to codes.take(15)),
            "radius exactly 50000" to mapOf("locationBias" to circle + ("radiusMeters" to 50000.0)),
            "lat 90 / lng 180" to mapOf("origin" to mapOf("lat" to 90.0, "lng" to 180.0)),
            "rectangle across the 180th meridian" to mapOf(
                "locationRestriction" to mapOf(
                    "type" to "rectangle",
                    "southwest" to mapOf("lat" to -20.0, "lng" to 170.0),
                    "northeast" to mapOf("lat" to -10.0, "lng" to -170.0),
                ),
            ),
        )
        for ((why, extra) in accepted) {
            assertTrue("expected OK for: $why", autocomplete(extra) is PlacesArgParsers.ParseResult.Ok)
        }
        val rejected = mapOf(
            "16 countries" to mapOf("countries" to codes),
            "alpha-3 country" to mapOf("countries" to listOf("CAN")),
            "radius 50000.1" to mapOf("locationBias" to circle + ("radiusMeters" to 50000.1)),
            "lat 90.0001" to mapOf("origin" to mapOf("lat" to 90.0001, "lng" to 0.0)),
        )
        for ((why, extra) in rejected) {
            assertTrue("expected INVALID_ARGUMENT for: $why", autocomplete(extra) is PlacesArgParsers.ParseResult.Err)
        }
    }
}
