package com.nosmai.moderation_agora_bridge_flutter

import android.content.Context
import android.graphics.Bitmap
import io.agora.base.VideoFrame
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.video.IVideoFrameObserver
import java.lang.reflect.Method
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Creates an Agora engine and taps its captured frames read-only, forwarding a
 * sampled subset to the Nosmai Moderation SDK. Nosmai is reached over reflection
 * (`com.nosmai.nosmai_moderation_sdk.NosmaiLiveCamera.pushExternalFrame`), so
 * this bridge links no Nosmai code and ships no models. The frame is never
 * modified — the outgoing Agora stream is untouched.
 */
class VideoModerationController(context: Context, appId: String) {

    private var rtcEngine: RtcEngine? = null

    // Convert + hand off on a worker; skip frames while one is in flight so a
    // slow device never backs up the capture thread.
    private val worker = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    private var frameCount = 0
    private val pushEveryN = 5   // ~3 frames/sec at 15 fps capture is plenty

    // Reflection handle into the Nosmai plugin's external-frame entry point.
    private val liveCamera: Any?
    private val pushExternalFrame: Method?

    init {
        var inst: Any? = null
        var method: Method? = null
        try {
            val cls = Class.forName("com.nosmai.nosmai_moderation_sdk.NosmaiLiveCamera")
            inst = cls.getField("INSTANCE").get(null)   // Kotlin `object` singleton
            method = cls.getMethod(
                "pushExternalFrame", Bitmap::class.java, Int::class.javaPrimitiveType
            )
        } catch (_: Throwable) {
            // nosmai_moderation_sdk not present or older — frames are dropped.
        }
        liveCamera = inst
        pushExternalFrame = method

        rtcEngine = RtcEngine.create(RtcEngineConfig().apply {
            mAppId = appId
            mContext = context.applicationContext
            mEventHandler = object : IRtcEngineEventHandler() {}
        })

        rtcEngine!!.registerVideoFrameObserver(object : IVideoFrameObserver {
            override fun onCaptureVideoFrame(sourceType: Int, videoFrame: VideoFrame?): Boolean {
                val vf = videoFrame ?: return true
                frameCount += 1
                if (pushExternalFrame == null) return true
                if (frameCount % pushEveryN != 0) return true
                if (!busy.compareAndSet(false, true)) return true   // drop-if-busy

                try {
                    val i420 = vf.buffer.toI420()
                    val w = i420.width
                    val h = i420.height
                    val y = copyPlane(i420.dataY, i420.strideY, h)
                    val u = copyPlane(i420.dataU, i420.strideU, (h + 1) / 2)
                    val v = copyPlane(i420.dataV, i420.strideV, (h + 1) / 2)
                    val sy = i420.strideY
                    val su = i420.strideU
                    val sv = i420.strideV
                    i420.release()

                    worker.execute {
                        try {
                            val bmp = i420ToBitmap(y, u, v, w, h, sy, su, sv)
                            // Rotation already applied by Agora (getRotationApplied), so 0.
                            pushExternalFrame.invoke(liveCamera, bmp, 0)
                        } catch (_: Throwable) {
                        } finally {
                            busy.set(false)
                        }
                    }
                } catch (_: Throwable) {
                    busy.set(false)
                }
                return true   // read-only: do not alter the outgoing frame
            }

            override fun onPreEncodeVideoFrame(sourceType: Int, videoFrame: VideoFrame?) = false
            override fun onMediaPlayerVideoFrame(videoFrame: VideoFrame?, mediaPlayerId: Int) = false
            override fun onRenderVideoFrame(channelId: String?, uid: Int, videoFrame: VideoFrame?) = false
            override fun getVideoFrameProcessMode() = IVideoFrameObserver.PROCESS_MODE_READ_ONLY
            override fun getVideoFormatPreference() = IVideoFrameObserver.VIDEO_PIXEL_I420
            override fun getRotationApplied() = true
            override fun getMirrorApplied() = false
            override fun getObservedFramePosition() = IVideoFrameObserver.POSITION_POST_CAPTURER
        })
    }

    fun nativeHandle(): Long = rtcEngine!!.nativeHandle

    fun dispose() {
        rtcEngine?.registerVideoFrameObserver(null)
        worker.shutdown()
        RtcEngine.destroy()
        rtcEngine = null
    }

    private fun copyPlane(buf: ByteBuffer, stride: Int, rows: Int): ByteArray {
        val dup = buf.duplicate()
        dup.rewind()
        val out = ByteArray(stride * rows)
        dup.get(out, 0, minOf(out.size, dup.remaining()))
        return out
    }

    // Integer BT.601 (video range) I420 -> ARGB_8888. No JPEG round-trip.
    private fun i420ToBitmap(
        y: ByteArray, u: ByteArray, v: ByteArray,
        w: Int, h: Int, sy: Int, su: Int, sv: Int
    ): Bitmap {
        val argb = IntArray(w * h)
        var idx = 0
        for (j in 0 until h) {
            val yRow = j * sy
            val uvRow = (j shr 1)
            for (i in 0 until w) {
                val yy = (y[yRow + i].toInt() and 0xFF) - 16
                val uu = (u[uvRow * su + (i shr 1)].toInt() and 0xFF) - 128
                val vv = (v[uvRow * sv + (i shr 1)].toInt() and 0xFF) - 128
                val r = (298 * yy + 409 * vv + 128) shr 8
                val g = (298 * yy - 100 * uu - 208 * vv + 128) shr 8
                val b = (298 * yy + 516 * uu + 128) shr 8
                argb[idx++] = (0xFF shl 24) or (clamp(r) shl 16) or (clamp(g) shl 8) or clamp(b)
            }
        }
        return Bitmap.createBitmap(argb, w, h, Bitmap.Config.ARGB_8888)
    }

    private fun clamp(x: Int) = if (x < 0) 0 else if (x > 255) 255 else x
}
