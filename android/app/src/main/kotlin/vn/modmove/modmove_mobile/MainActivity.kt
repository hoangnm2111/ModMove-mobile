package vn.modmove.modmove_mobile

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import android.content.Intent
import android.location.Geocoder
import java.util.Locale
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.modmove/customer_places")
            .setMethodCallHandler { call, result ->
                if (call.method !in listOf("search", "reverse")) {
                    result.notImplemented()
                } else if (!Geocoder.isPresent()) {
                    result.error("UNAVAILABLE", "Dịch vụ địa chỉ chưa sẵn sàng trên thiết bị.", null)
                } else {
                    Thread {
                        try {
                            val geocoder = Geocoder(applicationContext, Locale.forLanguageTag("vi-VN"))
                            @Suppress("DEPRECATION")
                            val addresses = if (call.method == "search") {
                                geocoder.getFromLocationName(call.argument<String>("query").orEmpty(), 5)
                            } else {
                                geocoder.getFromLocation(call.argument<Double>("latitude")!!,
                                    call.argument<Double>("longitude")!!, 1)
                            }
                            val values = addresses.orEmpty().map { address -> mapOf(
                                "address" to address.getAddressLine(0),
                                "latitude" to address.latitude, "longitude" to address.longitude) }
                            runOnUiThread { result.success(values) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("GEOCODE", "Không tìm được địa chỉ. Hãy nhập địa chỉ đầy đủ.", null) }
                        }
                    }.start()
                }
            }
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
