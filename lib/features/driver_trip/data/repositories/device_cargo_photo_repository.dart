import 'package:flutter/services.dart';
import '../../../onboarding/data/repositories/device_photo_repository.dart';
import '../../../onboarding/domain/entities/driver_application.dart';
import '../../domain/entities/trip_models.dart';
import '../../domain/repositories/driver_trip_repository.dart';

class DeviceCargoPhotoRepository implements CargoPhotoRepository {
  DeviceCargoPhotoRepository({DevicePhotoRepository? device})
    : _device = device ?? DevicePhotoRepository();
  final DevicePhotoRepository _device;
  @override
  Future<CargoPhoto?> pick(CargoPhotoKind kind, CargoPhotoSource source) async {
    if (source == CargoPhotoSource.sample) {
      final name = kind == CargoPhotoKind.overall
          ? 'mock-cargo-overall.png'
          : 'mock-cargo-secured.png';
      final data = await rootBundle.load('assets/images/$name');
      return CargoPhoto(
        kind: kind,
        name: name,
        bytes: data.buffer.asUint8List(),
      );
    }
    try {
      final photo = await _device.pick(
        source == CargoPhotoSource.camera
            ? PhotoSource.camera
            : PhotoSource.gallery,
      );
      if (photo == null) return null;
      return CargoPhoto(kind: kind, name: photo.name, bytes: photo.bytes);
    } on ApplicationFailure catch (e) {
      throw TripFailure(e.message);
    }
  }
}
