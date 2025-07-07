package com.rightbite.denisr

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding

class KlaviyoFlutterPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        KlaviyoMethodCallHandler.getInstance().onAttachedToEngine(
            binding.applicationContext,
            binding.binaryMessenger
        )

        KlaviyoEventChannelHandler.getInstance().onAttachedToEngine(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        KlaviyoMethodCallHandler.getInstance().onDetachedFromEngine()
    }
}
