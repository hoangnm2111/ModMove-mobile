import '../entities/trip_models.dart';

abstract interface class DriverLocationGateway {
  Future<GpsFix> current({bool requestPermission = false});
}

/// Optional lifecycle for a device location source that continues during a shift.
abstract interface class DriverLocationLifecycle {
  Future<void> startTracking();
  Future<void> stopTracking();
}

/// Settings are opened only after a user explicitly asks to recover location.
abstract interface class DriverLocationSettings {
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}
