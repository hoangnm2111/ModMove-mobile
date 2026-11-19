import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_location_gateway.dart';

class DeviceDriverLocation
    implements
        DriverLocationGateway,
        DriverLocationLifecycle,
        DriverLocationSettings {
  StreamSubscription<Position>? _positions;
  GpsFix? _latest;
  Future<void>? _starting;

  @override
  Future<void> startTracking() =>
      _starting ??= _start().whenComplete(() => _starting = null);

  Future<void> _start() async {
    if (_positions != null) return;
    await _checkPermission();
    _positions =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            // Use the same Android GPS source as current(). Some emulators
            // report fused-location unavailability despite a valid GPS fix.
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            intervalDuration: const Duration(seconds: 5),
            distanceFilter: 0,
            maxUpdateAge: Duration.zero,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'ModMove đang cập nhật vị trí',
              notificationText:
                  'Vị trí được chia sẻ khi bạn trực tuyến hoặc đang giao hàng.',
              notificationIcon: AndroidResource(
                name: 'ic_notification',
                defType: 'drawable',
              ),
              enableWakeLock: true,
              setOngoing: true,
            ),
          ),
        ).listen(
          (position) {
            _latest = GpsFix(
              GeoPoint(position.latitude, position.longitude),
              position.timestamp,
            );
          },
          onError: (Object error) {
            _latest = null;
            // A temporary acquisition error is not an instruction to restart
            // the foreground service on every five-second repository poll.
            if (error is! PermissionDeniedException &&
                error is! LocationServiceDisabledException) {
              return;
            }
            final old = _positions;
            _positions = null;
            unawaited(old?.cancel());
          },
          onDone: () => _positions = null,
        );
  }

  @override
  Future<void> stopTracking() async {
    try {
      await _starting;
    } on TripFailure {
      // Permission may have been revoked while starting the stream.
    }
    final old = _positions;
    _positions = null;
    _latest = null;
    await old?.cancel();
  }

  Future<void> _checkPermission({bool requestPermission = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DriverLocationFailure(
        DriverLocationIssue.serviceDisabled,
        'Vị trí của thiết bị đang tắt. Bật vị trí để xem đơn và cập nhật chuyến.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DriverLocationFailure(
        DriverLocationIssue.permissionBlocked,
        'Quyền vị trí đã bị chặn. Mở Cài đặt → Quyền → Vị trí và cho phép khi dùng ứng dụng.',
      );
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const DriverLocationFailure(
        DriverLocationIssue.permissionDenied,
        'ModMove chưa có quyền vị trí. Cấp quyền để xem đơn gần bạn và cập nhật chuyến.',
      );
    }
  }

  @override
  Future<GpsFix> current({bool requestPermission = false}) async {
    await _checkPermission(requestPermission: requestPermission);
    final latest = _latest;
    if (latest != null && latest.freshAt(DateTime.now())) return latest;
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
        throw const DriverLocationFailure(
          DriverLocationIssue.unavailable,
          'Vị trí GPS đã cũ. Vui lòng thử lại.',
        );
      }
      _latest = fix;
      return fix;
    } on TripFailure {
      rethrow;
    } catch (_) {
      throw const DriverLocationFailure(
        DriverLocationIssue.unavailable,
        'Chưa lấy được vị trí GPS. Kiểm tra tín hiệu rồi thử lại.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
