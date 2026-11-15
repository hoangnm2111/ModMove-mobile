import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../domain/entities/trip_models.dart';

/// Nguồn vị trí của tài xế. `null` = chưa lấy được (tắt GPS, từ chối quyền…).
abstract interface class DriverLocationSource {
  Future<GeoPoint?> current();
}

/// GPS thật của máy; nếu build có `DRIVER_FAKE_LAT/LNG` thì dùng toạ độ đó
/// (máy ảo Android mặc định ở Mỹ, ngoài bán kính ghép đơn của BE).
class DeviceLocationSource implements DriverLocationSource {
  const DeviceLocationSource();

  @override
  Future<GeoPoint?> current() async {
    final fake = AppConfig.driverFakeLocation;
    if (fake != null) return GeoPoint(fake.$1, fake.$2);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }
}
