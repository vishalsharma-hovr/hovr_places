package com.hovr.hovr_places

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Reads the Google API key from host-app manifest metadata.
 * The key is never returned to Dart and must never be logged.
 */
internal object PlacesApiKey {
    private const val TAG = "HovrPlaces"
    private const val META_GEO = "com.google.android.geo.API_KEY"
    private const val META_MAPS = "GOOGLE_MAPS_API_KEY"

    fun isValid(key: String?): Boolean {
        val trimmed = key?.trim().orEmpty()
        if (trimmed.isEmpty()) return false
        if (trimmed.startsWith("$(") && trimmed.endsWith(")")) return false
        if (trimmed.contains("YOUR_API_KEY", ignoreCase = true)) return false
        return true
    }

    fun fromManifest(context: Context): String {
        return try {
            val appInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
            val raw = appInfo.metaData?.getString(META_GEO)?.takeIf { it.isNotBlank() }
                ?: appInfo.metaData?.getString(META_MAPS).orEmpty()
            if (isValid(raw)) raw.trim() else ""
        } catch (error: Exception) {
            Log.e(TAG, "Failed to read Google API key from host manifest")
            ""
        }
    }
}
