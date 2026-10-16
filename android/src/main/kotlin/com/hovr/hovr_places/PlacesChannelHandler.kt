package com.hovr.hovr_places

import android.content.Context
import android.util.Log
import com.google.android.libraries.places.api.Places
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Task
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.CircularBounds
import com.google.android.libraries.places.api.model.LocationBias
import com.google.android.libraries.places.api.model.LocationRestriction
import com.google.android.libraries.places.api.model.RectangularBounds
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient
import com.google.android.libraries.places.api.net.SearchNearbyRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

internal class PlacesChannelHandler(
    context: Context,
    private val sessions: PlacesSessionStore = PlacesSessionStore(),
) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private var channel: MethodChannel? = null
    private var client: PlacesClient? = null
    private var clientLocale: Locale? = null

    // Main-thread only: method calls and Task listeners both run there.
    private val inFlight = HashMap<String, CancellationTokenSource>()

    fun attach(messenger: BinaryMessenger) {
        val next = MethodChannel(messenger, PlacesChannelConstants.CHANNEL_NAME)
        next.setMethodCallHandler(this)
        channel = next
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        client = null
        inFlight.values.forEach { it.cancel() }
        inFlight.clear()
        sessions.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            PlacesChannelConstants.METHOD_AUTOCOMPLETE ->
                withArgs(PlacesArgParsers.parseAutocomplete(call.arguments), result) {
                    handleAutocomplete(it, result)
                }
            PlacesChannelConstants.METHOD_PLACE_DETAILS ->
                withArgs(PlacesArgParsers.parsePlaceDetails(call.arguments), result) {
                    handlePlaceDetails(it, result)
                }
            PlacesChannelConstants.METHOD_SEARCH_NEARBY ->
                withArgs(PlacesArgParsers.parseSearchNearby(call.arguments), result) {
                    handleSearchNearby(it, result)
                }
            PlacesChannelConstants.METHOD_END_SESSION ->
                withArgs(PlacesArgParsers.parseEndSession(call.arguments), result) {
                    inFlight.remove(it.sessionToken)?.cancel()
                    sessions.endSession(it.sessionToken)
                    result.success(null)
                }
            else -> result.notImplemented()
        }
    }

    private inline fun <T> withArgs(
        parsed: PlacesArgParsers.ParseResult<T>,
        result: MethodChannel.Result,
        handle: (T) -> Unit,
    ) {
        when (parsed) {
            is PlacesArgParsers.ParseResult.Err ->
                result.error(PlacesChannelConstants.ERROR_INVALID_ARGUMENT, parsed.message, null)
            is PlacesArgParsers.ParseResult.Ok -> handle(parsed.value)
        }
    }

    /** With cancelPrevious, a newer autocomplete in the same session cancels the older one (CANCELLED). */
    private fun handleAutocomplete(args: PlacesArgParsers.AutocompleteArgs, result: MethodChannel.Result) {
        val client = placesClientOrError(result, args.language) ?: return
        val cancel = if (args.cancelPrevious) CancellationTokenSource() else null
        if (cancel != null) inFlight.put(args.sessionToken, cancel)?.cancel()
        val request = autocompleteRequest(args, sessions.tokenFor(args.sessionToken), cancel)
        client.findAutocompletePredictions(request).addOnCompleteListener { task ->
            if (cancel != null && inFlight[args.sessionToken] === cancel) inFlight.remove(args.sessionToken)
            reply(task, result) { response ->
                mapOf("predictions" to response.autocompletePredictions.map(PlacesResultMaps::predictionMap))
            }
        }
    }

    private fun handlePlaceDetails(args: PlacesArgParsers.PlaceDetailsArgs, result: MethodChannel.Result) {
        val client = placesClientOrError(result, null) ?: return
        val builder = FetchPlaceRequest.builder(args.placeId, PlacesResultMaps.placeFields(args.fields))
            .setSessionToken(sessions.tokenFor(args.sessionToken))
        args.regionCode?.let { builder.setRegionCode(it) }
        client.fetchPlace(builder.build()).addOnCompleteListener { task ->
            val place = if (task.isSuccessful) task.result.place else null
            val details = place?.let { PlacesResultMaps.placeDetailsMap(it, args.placeId) }
            if (place != null && details == null) {
                result.error(PlacesChannelConstants.ERROR_PLACE_ERROR, "Place has no coordinates", null)
            } else {
                reply(task, result) { details }
            }
        }
    }

    private fun handleSearchNearby(args: PlacesArgParsers.SearchNearbyArgs, result: MethodChannel.Result) {
        val client = placesClientOrError(result, null) ?: return
        val builder = SearchNearbyRequest.builder(
            CircularBounds.newInstance(latLng(args.area.center), args.area.radiusMeters),
            PlacesResultMaps.placeFields(args.fields),
        ).setRankPreference(
            if (args.rankByDistance) SearchNearbyRequest.RankPreference.DISTANCE
            else SearchNearbyRequest.RankPreference.POPULARITY,
        )
        args.types?.let { builder.setIncludedTypes(it) }
        args.maxResults?.let { builder.setMaxResultCount(it) }
        args.regionCode?.let { builder.setRegionCode(it) }
        client.searchNearby(builder.build()).addOnCompleteListener { task ->
            reply(task, result) { response ->
                // Places without coordinates are dropped, never sent as (0, 0).
                mapOf("places" to response.places.mapNotNull { PlacesResultMaps.placeDetailsMap(it, it.id ?: "") })
            }
        }
    }

    /** Replies exactly once: success, CANCELLED, or PLACE_ERROR. */
    private fun <R> reply(task: Task<R>, result: MethodChannel.Result, map: (R) -> Any?) {
        when {
            task.isCanceled ->
                result.error(PlacesChannelConstants.ERROR_CANCELLED, "Replaced by a newer request", null)
            task.isSuccessful -> result.success(map(task.result))
            else -> result.error(
                PlacesChannelConstants.ERROR_PLACE_ERROR,
                safeErrorMessage(task.exception ?: Exception()),
                (task.exception as? ApiException)?.let { mapOf("nativeCode" to it.statusCode) },
            )
        }
    }

    private fun autocompleteRequest(
        args: PlacesArgParsers.AutocompleteArgs,
        token: AutocompleteSessionToken,
        cancel: CancellationTokenSource?,
    ): FindAutocompletePredictionsRequest {
        val builder = FindAutocompletePredictionsRequest.builder()
            .setQuery(args.query)
            .setSessionToken(token)
        cancel?.let { builder.setCancellationToken(it.token) }
        val countries = args.countries
        if (!countries.isNullOrEmpty()) {
            builder.setCountries(countries)
        }
        args.origin?.let { builder.setOrigin(latLng(it)) }
        args.locationBias?.let { builder.setLocationBias(bounds(it) as LocationBias) }
        args.locationRestriction?.let {
            builder.setLocationRestriction(bounds(it) as LocationRestriction)
        }
        args.types?.let { builder.setTypesFilter(it) }
        args.regionCode?.let { builder.setRegionCode(it) }
        return builder.build()
    }

    private fun latLng(arg: PlacesArgParsers.LatLngArg) = LatLng(arg.lat, arg.lng)

    // Both SDK bounds types implement LocationBias and LocationRestriction.
    private fun bounds(area: PlacesArgParsers.AreaArg): Any = when (area) {
        is PlacesArgParsers.AreaArg.Circle ->
            CircularBounds.newInstance(latLng(area.center), area.radiusMeters)
        is PlacesArgParsers.AreaArg.Rectangle ->
            RectangularBounds.newInstance(latLng(area.southwest), latLng(area.northeast))
    }

    private fun placesClientOrError(
        result: MethodChannel.Result,
        language: String?,
    ): PlacesClient? {
        val placesClient = placesClientFor(language)
        if (placesClient == null) {
            result.error(
                PlacesChannelConstants.ERROR_MISSING_API_KEY,
                "Google Places API key is missing from the host AndroidManifest",
                null,
            )
        }
        return placesClient
    }

    /** The SDK only takes a language at init, so a new [language] re-initializes Places. */
    @Synchronized
    private fun placesClientFor(language: String?): PlacesClient? {
        val locale = language?.let { Locale.forLanguageTag(it) }
        val current = client
        if (current != null && Places.isInitialized() && (locale == null || locale == clientLocale)) {
            return current
        }
        val key = PlacesApiKey.fromManifest(appContext)
        if (key.isEmpty()) {
            Log.e(TAG, "Google Places API key is missing from the host AndroidManifest")
            return null
        }
        val nextLocale = locale ?: clientLocale ?: Locale.getDefault()
        Places.initializeWithNewPlacesApiEnabled(appContext, key, nextLocale)
        clientLocale = nextLocale
        return Places.createClient(appContext).also { client = it }
    }

    companion object {
        private const val TAG = "HovrPlaces"

        fun safeErrorMessage(error: Throwable): String {
            val message = error.message.orEmpty()
            if (message.contains("AIza") || message.contains("YOUR_API_KEY", ignoreCase = true)) {
                return "Places SDK request failed"
            }
            return message.ifBlank { "Places SDK request failed" }
        }
    }
}
