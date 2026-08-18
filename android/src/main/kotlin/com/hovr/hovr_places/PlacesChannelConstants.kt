package com.hovr.hovr_places

internal object PlacesChannelConstants {
    const val CHANNEL_NAME = "com.hovr/places"

    const val METHOD_AUTOCOMPLETE = "autocomplete"
    const val METHOD_PLACE_DETAILS = "placeDetails"
    const val METHOD_END_SESSION = "endSession"

    const val ERROR_INVALID_ARGUMENT = "INVALID_ARGUMENT"
    const val ERROR_MISSING_API_KEY = "MISSING_API_KEY"
    const val ERROR_PLACE_ERROR = "PLACE_ERROR"
    const val ERROR_UNIMPLEMENTED = "UNIMPLEMENTED"
}
