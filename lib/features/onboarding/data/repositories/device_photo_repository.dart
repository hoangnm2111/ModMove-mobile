import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/usecases/validate_driver_application.dart';

class DevicePhotoRepository implements DocumentPhotoRepository {
  DevicePhotoRepository({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  @override
  Future<SelectedPhoto?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      final length = await file.length();
      if (length > 5 * 1024 * 1024) {
        throw const ApplicationFailure(
          'Ảnh vượt quá 5 MB. Vui lòng chọn ảnh nhỏ hơn.',
        );
      }
      final bytes = await file.readAsBytes();
      final error = const ValidateDriverApplication().image(file.name, bytes);
      if (error != null) throw ApplicationFailure(error);
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        frame.image.dispose();
        codec.dispose();
      } catch (_) {
        throw const ApplicationFailure(
          'Không đọc được ảnh. Vui lòng chọn ảnh khác.',
        );
      }
      return SelectedPhoto(file.name, bytes);
    } on PlatformException {
      throw const ApplicationFailure(
        'Không mở được camera hoặc thư viện. Vui lòng kiểm tra quyền truy cập và thử lại.',
      );
    }
  }
}
