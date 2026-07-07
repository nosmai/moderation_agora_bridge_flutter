package com.nosmai.moderation_agora_bridge_flutter

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Thin bridge: creates an Agora engine with a read-only Nosmai frame observer
 * and hands its native handle to Flutter. Moderation results are emitted by the
 * `nosmai_moderation_sdk` plugin's own live event channel, not by this bridge.
 */
class ModerationAgoraBridgeFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var controller: VideoModerationController? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "moderation_agora_bridge_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNativeHandle" -> {
                val appId = call.argument<String>("appId")
                if (appId.isNullOrEmpty()) {
                    result.error("NO_APP_ID", "agoraAppId is required", null)
                    return
                }
                val ctx = context
                if (ctx == null) {
                    result.error("NO_CONTEXT", "No application context", null)
                    return
                }
                try {
                    controller?.dispose()
                    controller = VideoModerationController(ctx, appId)
                    result.success(controller!!.nativeHandle())
                } catch (e: Throwable) {
                    result.error("ENGINE_CREATE_FAILED", e.message, null)
                }
            }
            // The Flutter side already switched the shared engine; the observer
            // re-detects front/back per frame, so this is a reserved no-op that
            // keeps the API parallel across platforms.
            "notifyCameraSwitch" -> result.success(null)
            "disposeNative" -> {
                controller?.dispose()
                controller = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        controller?.dispose()
        controller = null
        context = null
    }
}
