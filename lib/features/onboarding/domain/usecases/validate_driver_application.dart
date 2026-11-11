import 'dart:typed_data';
import '../entities/driver_application.dart';

class ValidateDriverApplication {
  const ValidateDriverApplication();

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
    // Khớp validator của BE: CCCD 9–12 chữ số; GPLX 8–20 chữ hoặc số.
    if (!RegExp(r'^\d{9,12}$').hasMatch((fields['citizenId'] ?? '').trim()))
      'citizenId': 'CCCD cần 9 đến 12 chữ số.',
    if (!RegExp(r'^[0-9A-Za-z]{8,20}$').hasMatch((fields['license'] ?? '').trim()))
      'license': 'GPLX cần 8 đến 20 chữ hoặc số.',
  };

  Map<String, String> vehicle(Map<String, String> fields) {
    final errors = <String, String>{};
    if (!RegExp(
      r'^\d{2}[A-Z]{1,2}-?\d{3}\.?\d{2}$',
    ).hasMatch((fields['plate'] ?? '').trim().toUpperCase())) {
      errors['plate'] = 'Kiểm tra biển số xe.';
    }
    for (final field in ['payload', 'length', 'width', 'height']) {
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
  }) => DocumentKind.values
      .where((kind) => !personalOnly || kind.index < 2)
      .where(
        (kind) =>
            !(application.documents[kind]?.hasImage ?? false) ||
            (application.documents[kind]!.rejectionReason != null &&
                !application.documents[kind]!.replaced),
      )
      .toList();
}
