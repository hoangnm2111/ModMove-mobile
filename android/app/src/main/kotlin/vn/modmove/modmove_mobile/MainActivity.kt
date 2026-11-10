package vn.modmove.modmove_mobile

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.modmove/maps_configuration")
            .setMethodCallHandler { call, result ->
                if (call.method == "isConfigured") {
                    @Suppress("DEPRECATION")
                    val metadata = packageManager.getApplicationInfo(
                        packageName, PackageManager.GET_META_DATA
                    ).metaData
                    val key = metadata?.getString("com.google.android.geo.API_KEY").orEmpty()
                    // Expose only presence; the SDK reads the key from the manifest.
                    result.success(key.isNotBlank() && !key.startsWith("YOUR_"))
                } else {
                    result.notImplemented()
                }
            }
    }
}
