package com.hovr.hovr_places

import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import java.util.concurrent.ConcurrentHashMap

/** Maps Dart-owned UUID strings to Places SDK session tokens. */
internal class PlacesSessionStore {
    private val tokens = ConcurrentHashMap<String, AutocompleteSessionToken>()

    fun tokenFor(sessionToken: String): AutocompleteSessionToken {
        return tokens.getOrPut(sessionToken) { AutocompleteSessionToken.newInstance() }
    }

    fun endSession(sessionToken: String) {
        tokens.remove(sessionToken)
    }

    fun clear() {
        tokens.clear()
    }
}
