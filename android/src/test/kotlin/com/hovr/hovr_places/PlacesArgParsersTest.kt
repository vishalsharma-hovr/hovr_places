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
}
