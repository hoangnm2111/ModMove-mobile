import 'dart:typed_data';
import '../entities/driver_application.dart';

class ValidateDriverApplication {
  const ValidateDriverApplication({this.backendContract = false});
  final bool backendContract;
  List<DocumentKind> get requiredDocuments => backendContract
      ? const [
          DocumentKind.licenseFront,
          DocumentKind.licenseBack,
          DocumentKind.registration,
          DocumentKind.inspection,
          DocumentKind.vehicle,
        ]
      : DocumentKind.values;

  String? image(String name, Uint8List bytes) {
    if (bytes.length > 5 * 1024 * 1024) {
      return 'Ảnh vượt quá 5 MB. Vui lòng chọn ảnh nhỏ hơn.';
    }
    final lower = name.toLowerCase();
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    final png =
        bytes.length >= 8 &&
        signature.indexed.every((entry) => bytes[entry.$1] == entry.$2);
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!(png && lower.endsWith('.png')) &&
        !(jpg && (lower.endsWith('.jpg') || lower.endsWith('.jpeg')))) {
      return 'Chỉ hỗ trợ ảnh JPG hoặc PNG hợp lệ.';
    }
    return null;
  }

  Map<String, String> personal(Map<String, String> fields) => {
    if (!RegExp(
      backendContract ? r'^\d{9,12}$' : r'^\d{12}$',
    ).hasMatch((fields['citizenId'] ?? '').trim()))
      'citizenId': backendContract
          ? 'CMND/CCCD cần 9–12 chữ số.'
          : 'CCCD cần đủ 12 chữ số.',
    if (!RegExp(
      backendContract ? r'^[0-9A-Za-z]{8,20}$' : r'^\d{12}$',
    ).hasMatch((fields['license'] ?? '').trim()))
      'license': backendContract
          ? 'GPLX cần 8–20 chữ cái hoặc chữ số.'
          : 'GPLX cần đủ 12 chữ số.',
  };

  Map<String, String> vehicle(Map<String, String> fields) {
    final errors = <String, String>{};
    if (!RegExp(
      backendContract
          ? r'^[0-9A-Z.\- ]{5,15}$'
          : r'^\d{2}[A-Z]{1,2}-?\d{3}\.?\d{2}$',
    ).hasMatch((fields['plate'] ?? '').trim().toUpperCase())) {
      errors['plate'] = 'Kiểm tra biển số xe.';
    }
    for (final field
        in backendContract
            ? ['payload']
            : ['payload', 'length', 'width', 'height']) {
      final value = double.tryParse((fields[field] ?? '').replaceAll(',', '.'));
      if (value == null || !value.isFinite || value <= 0) {
        errors[field] = 'Nhập số lớn hơn 0.';
      }
    }
    return errors;
  }

  List<DocumentKind> missingDocuments(
    DriverApplication application, {
    bool personalOnly = false,
  }) => requiredDocuments
      .where((kind) => !personalOnly || kind.index < 4)
      .where(
        (kind) =>
            !(application.documents[kind]?.hasImage ?? false) ||
            (application.documents[kind]!.rejectionReason != null &&
                !application.documents[kind]!.replaced),
      )
      .toList();
}
