import '../../../../core/format/formatters.dart';
import '../../domain/entities/driver_application.dart';

extension DocumentDisplay on DocumentKind {
  String get label => switch (this) {
    DocumentKind.licenseFront => 'GPLX · Mặt trước',
    DocumentKind.licenseBack => 'GPLX · Mặt sau',
    DocumentKind.registration => 'Đăng ký xe',
    DocumentKind.inspection => 'Giấy đăng kiểm',
    DocumentKind.vehicle => 'Ảnh phương tiện',
    DocumentKind.citizenIdFront => 'CCCD · Mặt trước',
    DocumentKind.citizenIdBack => 'CCCD · Mặt sau',
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
  return dateTime(value);
}
