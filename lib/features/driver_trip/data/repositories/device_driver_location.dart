import 'package:geolocator/geolocator.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_location_gateway.dart';

class DeviceDriverLocation implements DriverLocationGateway {
  @override
  Future<GpsFix> current({bool requestPermission = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const TripFailure('Hãy bật GPS của thiết bị để nhận đơn.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw const TripFailure(
        'Cần quyền vị trí. Mở Cài đặt → Ứng dụng → ModMove → Quyền → Vị trí.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          forceLocationManager: true,
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        ),
      );
      final fix = GpsFix(
        GeoPoint(position.latitude, position.longitude),
        position.timestamp,
      );
      if (!fix.freshAt(DateTime.now())) {
        throw const TripFailure('Vị trí GPS đã cũ. Vui lòng thử lại.');
      }
      return fix;
    } on TripFailure {
      rethrow;
    } catch (_) {
      throw const TripFailure(
        'Chưa lấy được vị trí GPS. Kiểm tra tín hiệu rồi thử lại.',
      );
    }
  }
}
