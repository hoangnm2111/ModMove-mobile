package vn.modmove.modmove_mobile

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var paymentChannel: MethodChannel? = null

    private fun paymentReturn(intent: Intent?): String? {
        val uri = intent?.data ?: return null
        return if (intent.action == Intent.ACTION_VIEW && uri.scheme == "modmove" &&
            uri.host == "orders" && uri.path in listOf("/success", "/cancel")) {
            uri.toString()
        } else null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        paymentReturn(intent)?.let {
            paymentChannel?.invokeMethod("paymentReturn", it)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        paymentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.modmove/payment_return")
        paymentChannel?.setMethodCallHandler { call, result ->
            if (call.method == "initialReturn") {
                result.success(paymentReturn(intent))
                intent?.data = null
            } else {
                result.notImplemented()
            }
        }
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
