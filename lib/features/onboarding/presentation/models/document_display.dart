import '../../domain/entities/driver_application.dart';

extension DocumentDisplay on DocumentKind {
  String get label => switch (this) {
    DocumentKind.citizenFront => 'CCCD · Mặt trước',
    DocumentKind.citizenBack => 'CCCD · Mặt sau',
    DocumentKind.licenseFront => 'GPLX · Mặt trước',
    DocumentKind.licenseBack => 'GPLX · Mặt sau',
    DocumentKind.registration => 'Đăng ký xe',
    DocumentKind.inspection => 'Giấy đăng kiểm',
    DocumentKind.vehicle => 'Ảnh phương tiện',
  };
  String get preview => switch (this) {
    DocumentKind.registration => 'registration',
    DocumentKind.inspection => 'inspection',
    DocumentKind.vehicle => 'truck-white',
    _ => 'identity',
  };
}

String formatStamp(DateTime? value) {
  if (value == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} · ${two(value.day)}/${two(value.month)}/${value.year}';
}
