package com.xzgg.idwm

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.xzgg.idwm/jpeg"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "encodeJpeg") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val png = call.argument<ByteArray>("png")
                val quality = call.argument<Int>("quality") ?: 92
                if (png == null) {
                    result.error("BAD_ARGS", "缺少 png 参数", null)
                    return@setMethodCallHandler
                }

                var bitmap: Bitmap? = null
                try {
                    bitmap = BitmapFactory.decodeByteArray(png, 0, png.size)
                    if (bitmap == null) {
                        result.error("DECODE_FAILED", "PNG 解码失败", null)
                        return@setMethodCallHandler
                    }
                    val out = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                    result.success(out.toByteArray())
                } catch (e: Exception) {
                    result.error("ENCODE_FAILED", e.message, null)
                } finally {
                    bitmap?.recycle()
                }
            }
    }
}
