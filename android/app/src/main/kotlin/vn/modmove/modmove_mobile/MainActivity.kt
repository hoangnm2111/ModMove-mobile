package vn.modmove.modmove_mobile

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
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
