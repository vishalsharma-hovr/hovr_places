package com.hovr.hovr_places

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** Registers the `com.hovr/places` method channel. */
class HovrPlacesPlugin : FlutterPlugin {
    private var handler: PlacesChannelHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val next = PlacesChannelHandler(binding.applicationContext)
        next.attach(binding.binaryMessenger)
        handler = next
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        handler?.detach()
        handler = null
    }
}
