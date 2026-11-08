import 'package:flutter/services.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/repositories/driver_repository.dart';

/// Supplies an explicitly labelled sample while retaining native picker support.
class DemoPhotoRepository implements DocumentPhotoRepository {
  const DemoPhotoRepository(this.device);
  final DocumentPhotoRepository device;
  @override
  Future<SelectedPhoto?> pick(PhotoSource source) async {
    if (source != PhotoSource.sample) return device.pick(source);
    final asset = await rootBundle.load('assets/images/demo-document.png');
    return SelectedPhoto(
      'demo-document.png',
      asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
    );
  }
}
