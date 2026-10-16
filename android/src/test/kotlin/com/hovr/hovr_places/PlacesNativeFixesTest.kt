package com.hovr.hovr_places

import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.google.android.libraries.places.api.model.Place
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class PlacesNativeFixesTest {
    @Test
    fun placeDetailsMap_withoutLocation_isNullSoNoZeroZeroPickup() {
        val place = Place.builder().setId("p1").build()
        assertNull(
            "a place with no location must not be sent to Dart as 0, 0",
            PlacesResultMaps.placeDetailsMap(place, "p1"),
        )
    }

    @Test
    fun placeDetailsMap_mapsLocationAddressAndTypes() {
        val place = Place.builder()
            .setId("p1")
            .setLocation(LatLng(43.65, -79.38))
            .setFormattedAddress("Toronto")
            .setPlaceTypes(listOf("transit_station"))
            .build()
        val map = PlacesResultMaps.placeDetailsMap(place, "p1")
        assertEquals("latitude", 43.65, map?.get("lat"))
        assertEquals("longitude", -79.38, map?.get("lng"))
        assertEquals("formatted address", "Toronto", map?.get("formattedAddress"))
        assertEquals("types", listOf("transit_station"), map?.get("types"))
    }

    @Test
    fun sessionStore_sameDartTokenReusesSdkToken() {
        val store = PlacesSessionStore()
        assertSame(
            "autocomplete and details must share one SDK token for billing",
            store.tokenFor("sess-1"),
            store.tokenFor("sess-1"),
        )
    }

    @Test
    fun sessionStore_dropsOldestBeyondCap() {
        val store = PlacesSessionStore(maxSessions = 2)
        val first = store.tokenFor("a")
        store.tokenFor("b")
        store.tokenFor("c")
        assertEquals("store must never hold more than the cap", 2, store.size())
        assertNotSame(
            "oldest session 'a' should have been dropped and get a new token",
            first,
            store.tokenFor("a"),
        )
    }

    @Test
    fun placeFields_addsOnlyRequestedOptionalFields() {
        val fields = PlacesResultMaps.placeFields(listOf("name", "plusCode"))
        assertEquals(
            "base fields plus DISPLAY_NAME and PLUS_CODE, nothing else billed",
            PlacesResultMaps.BASE_FIELDS + listOf(Place.Field.DISPLAY_NAME, Place.Field.PLUS_CODE),
            fields,
        )
    }

    @Test
    fun placeDetailsMap_mapsNameAndViewport() {
        val place = Place.builder()
            .setId("p1")
            .setLocation(LatLng(43.68, -79.63))
            .setDisplayName("Toronto Pearson")
            .setViewport(LatLngBounds(LatLng(43.66, -79.65), LatLng(43.70, -79.60)))
            .build()
        val map = PlacesResultMaps.placeDetailsMap(place, "p1")
        assertEquals("name", "Toronto Pearson", map?.get("name"))
        assertEquals(
            "viewport",
            mapOf(
                "southwest" to mapOf("lat" to 43.66, "lng" to -79.65),
                "northeast" to mapOf("lat" to 43.70, "lng" to -79.60),
            ),
            map?.get("viewport"),
        )
    }
}
