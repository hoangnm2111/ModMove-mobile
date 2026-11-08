import '../entities/trip_models.dart';

abstract interface class DriverLocationGateway {
  Future<GpsFix> current({bool requestPermission = false});
}
