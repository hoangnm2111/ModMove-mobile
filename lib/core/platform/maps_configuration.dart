import 'package:flutter/services.dart';

/// Reads the configuration actually compiled into the Android manifest.
/// Key presence does not imply that Google has authorized the key or billing.
class MapsConfiguration {
  static const _channel = MethodChannel('vn.modmove/maps_configuration');

  static Future<bool> isConfigured() async {
    try {
      return await _channel
              .invokeMethod<bool>('isConfigured')
              .timeout(const Duration(seconds: 2), onTimeout: () => false) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
