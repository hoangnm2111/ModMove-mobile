import 'package:flutter/services.dart';

/// Reads the mobile MapVina key supplied locally at build time.
class MapsConfiguration {
  static const _channel = MethodChannel('vn.modmove/maps_configuration');

  static Future<String> apiKey() async {
    const defined = String.fromEnvironment('MAPVINA_API_KEY');
    var value = defined.trim();
    try {
      if (value.isEmpty) {
        value =
            (await _channel
                        .invokeMethod<String>('mapvinaApiKey')
                        .timeout(
                          const Duration(seconds: 2),
                          onTimeout: () => null,
                        ) ??
                    '')
                .trim();
      }
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
    return value.startsWith('YOUR_') || value == 'REPLACE_ME' ? '' : value;
  }

  static Future<bool> isConfigured() async => (await apiKey()).isNotEmpty;
}
