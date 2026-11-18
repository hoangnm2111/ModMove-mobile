import 'package:geolocator/geolocator.dart';

import '../domain/entities/trip_models.dart';

/// Một điểm GPS: toạ độ, độ chính xác (mét), cờ vị trí giả lập của Android và giờ đo của máy.
class GpsSample {
  const GpsSample(this.point, {this.accuracy, this.isMocked = false, required this.at});
  final GeoPoint point;
  final double? accuracy;
  final bool isMocked;
  final DateTime at;
}

/// Nguồn vị trí của tài xế. `null` = chưa lấy được (tắt GPS, từ chối quyền…).
abstract interface class DriverLocationSource {
  /// Một điểm ngay lúc này (kèm xin quyền): dùng khi bật Online.
  Future<GpsSample?> current();

  /// Luồng điểm theo thời gian khi Online. Lỗi (tắt GPS, mất quyền) đi qua luồng dưới dạng error.
  Stream<GpsSample> watch();
}

/// GPS thật của máy. Máy ảo test bằng Extended Controls → Location, không có toạ độ cố định trong app.
class DeviceLocationSource implements DriverLocationSource {
  const DeviceLocationSource();

  static GpsSample _sample(Position p) => GpsSample(GeoPoint(p.latitude, p.longitude), accuracy: p.accuracy, isMocked: p.isMocked, at: p.timestamp);

  Future<bool> _permitted({required bool ask}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) permission = await Geolocator.requestPermission();
    return permission != LocationPermission.denied && permission != LocationPermission.deniedForever;
  }

  @override
  Future<GpsSample?> current() async {
    try {
      if (!await _permitted(ask: true)) return null;
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
      return _sample(position);
    } catch (_) {
      return null;
    }
  }

  /// `distanceFilter` phải là 0: xe đứng yên vẫn cần điểm mới mỗi 5 giây, nếu không nút giao hàng
  /// khoá sau 30 giây (GB-52) và BE coi tài xế mất kết nối sau 5 phút (6.4).
  /// Foreground service giữ luồng sống khi app ra nền (B1); thông báo là bắt buộc của Android.
  @override
  Stream<GpsSample> watch() async* {
    if (!await _permitted(ask: false)) throw const LocationServiceDisabledException();
    yield* Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'ModMove',
          notificationText: 'ModMove đang chia sẻ vị trí khi bạn Online',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).map(_sample);
  }
}
