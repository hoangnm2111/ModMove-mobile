import 'entities/driver_application.dart';

/// Lý do từ chối hồ sơ do Admin nhập, tách theo từng giấy tờ để tài xế chỉ phải làm lại đúng mục bị từ chối.
class RejectionSummary {
  const RejectionSummary(this.documents, this.others, {this.vehicleInfo});

  /// Giấy tờ bị từ chối → lý do (phần sau dấu `:`).
  final Map<DocumentKind, String> documents;

  /// Lý do không gắn với giấy tờ nào (biển số, ghi chú khác…), giữ nguyên chữ của Admin.
  final List<String> others;

  /// Lý do khi mục thông tin xe (loại xe, biển số, tải trọng) bị từ chối; null nếu không bị từ chối.
  final String? vehicleInfo;

  static const empty = RejectionSummary({}, []);
}

const _itemKeys = <String, DocumentKind>{
  'LicenseFront': DocumentKind.licenseFront,
  'LicenseBack': DocumentKind.licenseBack,
  'VehicleRegistration': DocumentKind.registration,
  'VehicleInspection': DocumentKind.inspection,
  'VehiclePhoto': DocumentKind.vehicle,
  'CitizenIdFront': DocumentKind.citizenIdFront,
  'CitizenIdBack': DocumentKind.citizenIdBack,
};

/// Khoá mục theo BE của từng giấy tờ (dùng khi nộp lại hồ sơ).
String itemKeyOf(DocumentKind kind) => _itemKeys.entries.firstWhere((e) => e.value == kind).key;

/// Danh sách mục bị từ chối có cấu trúc do BE trả về: `[{key, reason}]`.
RejectionSummary summarizeRejectedItems(Iterable<Map<String, dynamic>> items) {
  final documents = <DocumentKind, String>{};
  final others = <String>[];
  String? vehicleInfo;
  for (final item in items) {
    final key = '${item['key'] ?? ''}';
    final reason = '${item['reason'] ?? ''}'.trim();
    final kind = _itemKeys[key];
    if (kind != null) {
      documents[kind] = reason.isEmpty ? 'Cần cập nhật ảnh.' : reason;
    } else if (key == 'VehicleInfo') {
      vehicleInfo = reason.isEmpty ? 'Cần cập nhật thông tin xe.' : reason;
    } else if (reason.isNotEmpty) {
      others.add(reason);
    }
  }
  return RejectionSummary(documents, others, vehicleInfo: vehicleInfo);
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[–—·\-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

const _aliases = <DocumentKind, List<String>>{
  DocumentKind.licenseFront: ['bằng lái mặt trước', 'gplx mặt trước'],
  DocumentKind.licenseBack: ['bằng lái mặt sau', 'gplx mặt sau'],
  DocumentKind.registration: ['đăng ký xe'],
  DocumentKind.inspection: ['giấy đăng kiểm', 'đăng kiểm'],
  DocumentKind.vehicle: ['ảnh xe', 'ảnh phương tiện'],
  DocumentKind.citizenIdFront: ['cccd mặt trước'],
  DocumentKind.citizenIdBack: ['cccd mặt sau'],
};

/// Admin chọn mục cần sửa trên web nên mỗi lý do có dạng `<tên mục>: <lý do>`; gắn vào đúng giấy tờ theo tên mục.
RejectionSummary summarizeRejection(Iterable<String> reasons) {
  final documents = <DocumentKind, String>{};
  final others = <String>[];
  for (final raw in reasons) {
    final reason = raw.trim();
    if (reason.isEmpty) continue;
    final colon = reason.indexOf(':');
    final label = _norm(colon < 0 ? reason : reason.substring(0, colon));
    DocumentKind? kind;
    for (final entry in _aliases.entries) {
      if (entry.value.contains(label)) kind = entry.key;
    }
    if (kind == null) {
      others.add(reason);
    } else {
      documents[kind] = colon < 0 ? 'Cần cập nhật ảnh.' : reason.substring(colon + 1).trim();
    }
  }
  return RejectionSummary(documents, others);
}
