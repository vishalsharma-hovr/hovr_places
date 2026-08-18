package com.hovr.hovr_places

import android.content.Context
import android.util.Log
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class PlacesChannelHandler(
    context: Context,
    private val sessions: PlacesSessionStore = PlacesSessionStore(),
) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        val next = MethodChannel(messenger, PlacesChannelConstants.CHANNEL_NAME)
        next.setMethodCallHandler(this)
        channel = next
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        sessions.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            PlacesChannelConstants.METHOD_AUTOCOMPLETE -> handleAutocomplete(call, result)
            PlacesChannelConstants.METHOD_PLACE_DETAILS -> handlePlaceDetails(call, result)
            PlacesChannelConstants.METHOD_END_SESSION -> handleEndSession(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleAutocomplete(call: MethodCall, result: MethodChannel.Result) {
        when (val parsed = PlacesArgParsers.parseAutocomplete(call.arguments)) {
            is PlacesArgParsers.ParseResult.Err -> {
                result.error(PlacesChannelConstants.ERROR_INVALID_ARGUMENT, parsed.message, null)
            }
            is PlacesArgParsers.ParseResult.Ok -> {
                val client = placesClientOrError(result) ?: return
                val token = sessions.tokenFor(parsed.value.sessionToken)
                val request = autocompleteRequest(parsed.value, token)
                client.findAutocompletePredictions(request)
                    .addOnSuccessListener { response ->
                        val predictions = response.autocompletePredictions.map { prediction ->
                            mapOf(
                                "placeId" to prediction.placeId,
                                "primaryText" to prediction.getPrimaryText(null).toString(),
                                "secondaryText" to prediction.getSecondaryText(null).toString(),
                                "fullText" to prediction.getFullText(null).toString(),
                            )
                        }
                        result.success(mapOf("predictions" to predictions))
                    }
                    .addOnFailureListener { error ->
                        result.error(
                            PlacesChannelConstants.ERROR_PLACE_ERROR,
                            safeErrorMessage(error),
                            null,
                        )
                    }
            }
        }
    }

    private fun handlePlaceDetails(call: MethodCall, result: MethodChannel.Result) {
        when (val parsed = PlacesArgParsers.parsePlaceDetails(call.arguments)) {
            is PlacesArgParsers.ParseResult.Err -> {
                result.error(PlacesChannelConstants.ERROR_INVALID_ARGUMENT, parsed.message, null)
            }
            is PlacesArgParsers.ParseResult.Ok -> {
                val client = placesClientOrError(result) ?: return
                val token = sessions.tokenFor(parsed.value.sessionToken)
                val fields = listOf(
                    Place.Field.ID,
                    Place.Field.LAT_LNG,
                    Place.Field.ADDRESS,
                    Place.Field.TYPES,
                )
                val request = FetchPlaceRequest.builder(parsed.value.placeId, fields)
                    .setSessionToken(token)
                    .build()
                client.fetchPlace(request)
                    .addOnSuccessListener { response ->
                        result.success(placeDetailsMap(response.place, parsed.value.placeId))
                    }
                    .addOnFailureListener { error ->
                        result.error(
                            PlacesChannelConstants.ERROR_PLACE_ERROR,
                            safeErrorMessage(error),
                            null,
                        )
                    }
            }
        }
    }

    private fun handleEndSession(call: MethodCall, result: MethodChannel.Result) {
        when (val parsed = PlacesArgParsers.parseEndSession(call.arguments)) {
            is PlacesArgParsers.ParseResult.Err -> {
                result.error(PlacesChannelConstants.ERROR_INVALID_ARGUMENT, parsed.message, null)
            }
            is PlacesArgParsers.ParseResult.Ok -> {
                sessions.endSession(parsed.value.sessionToken)
                result.success(null)
            }
        }
    }

    private fun autocompleteRequest(
        args: PlacesArgParsers.AutocompleteArgs,
        token: AutocompleteSessionToken,
    ): FindAutocompletePredictionsRequest {
        val builder = FindAutocompletePredictionsRequest.builder()
            .setQuery(args.query)
            .setSessionToken(token)
        val countries = args.countries
        if (!countries.isNullOrEmpty()) {
            builder.setCountries(countries)
        }
        return builder.build()
    }

    private fun placesClientOrError(result: MethodChannel.Result): PlacesClient? {
        if (!ensurePlacesInitialized()) {
            result.error(
                PlacesChannelConstants.ERROR_MISSING_API_KEY,
                "Google Places API key is missing from the host AndroidManifest",
                null,
            )
            return null
        }
        return Places.createClient(appContext)
    }

    @Synchronized
    private fun ensurePlacesInitialized(): Boolean {
        if (Places.isInitialized()) return true
        val key = PlacesApiKey.fromManifest(appContext)
        if (key.isEmpty()) {
            Log.e(TAG, "Google Places API key is missing from the host AndroidManifest")
            return false
        }
        Places.initialize(appContext, key)
        return Places.isInitialized()
    }

    companion object {
        private const val TAG = "HovrPlaces"

        fun placeDetailsMap(place: Place, requestedPlaceId: String): Map<String, Any?> {
            val latLng = place.latLng
            val types = place.types?.map { it.toString() } ?: emptyList()
            return mapOf(
                "placeId" to (place.id ?: requestedPlaceId),
                "lat" to (latLng?.latitude ?: 0.0),
                "lng" to (latLng?.longitude ?: 0.0),
                "formattedAddress" to (place.address ?: ""),
                "types" to types,
            )
        }

        fun safeErrorMessage(error: Throwable): String {
            val message = error.message.orEmpty()
            if (message.contains("AIza") || message.contains("YOUR_API_KEY", ignoreCase = true)) {
                return "Places SDK request failed"
            }
            return message.ifBlank { "Places SDK request failed" }
        }
    }
}
