package vn.modmove.modmove_mobile

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.github.mapvina.android.MapVina
import io.github.mapvina.android.WellKnownTileServer

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // mapvina_gl 1.0.1 calls MapVina.getInstance(context) on every map creation, which resets
        // the API key to null; the native SDK then aborts ("You must provide API key for tile
        // sources"). Dart re-sets the key here after the map exists and before loading the style.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.modmove/mapvina")
            .setMethodCallHandler { call, result ->
                val key = call.arguments as? String
                if (call.method == "setApiKey" && !key.isNullOrBlank()) {
                    MapVina.getInstance(applicationContext, key, WellKnownTileServer.MapVina)
                    MapVina.setApiKey(key) // also pushes the key into the native FileSource
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        // Mở cài đặt thông báo của ứng dụng khi người dùng đã từ chối quyền.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.modmove/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "openSettings") {
                    startActivity(Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName))
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
