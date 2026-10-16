package com.hovr.hovr_places

import com.google.android.libraries.places.api.model.AutocompleteSessionToken

/**
 * Maps Dart-owned UUID strings to Places SDK session tokens. Holds at most
 * [maxSessions] so sessions Dart never closes cannot pile up; the oldest goes first.
 */
internal class PlacesSessionStore(private val maxSessions: Int = MAX_SESSIONS) {
    private val tokens = object : LinkedHashMap<String, AutocompleteSessionToken>() {
        override fun removeEldestEntry(
            eldest: MutableMap.MutableEntry<String, AutocompleteSessionToken>,
        ): Boolean = size > maxSessions
    }

    @Synchronized
    fun tokenFor(sessionToken: String): AutocompleteSessionToken {
        return tokens.getOrPut(sessionToken) { AutocompleteSessionToken.newInstance() }
    }

    @Synchronized
    fun endSession(sessionToken: String) {
        tokens.remove(sessionToken)
    }

    @Synchronized
    fun clear() {
        tokens.clear()
    }

    @Synchronized
    fun size(): Int = tokens.size

    companion object {
        const val MAX_SESSIONS = 32
    }
}
