import '../entities/trip_models.dart';
import '../../../../core/config/platform_config.dart';

class ValidateCargoPhoto {
  const ValidateCargoPhoto();
  void call(CargoPhoto photo) {
    final bytes = photo.bytes;
    final name = photo.name.toLowerCase();
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (bytes.isEmpty ||
        bytes.length > AppRules.rules.maxPhotoSizeMb * 1024 * 1024 ||
        !(name.endsWith('.png') && png ||
            (name.endsWith('.jpg') || name.endsWith('.jpeg')) && jpeg)) {
      throw TripFailure(
        'Chọn ảnh JPG/PNG hợp lệ, dung lượng tối đa ${AppRules.rules.maxPhotoSizeMb} MB.',
      );
    }
  }
}
