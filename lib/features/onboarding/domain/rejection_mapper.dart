import 'entities/driver_application.dart';

/// Lý do từ chối hồ sơ do Admin nhập, tách theo từng giấy tờ để tài xế chỉ phải làm lại đúng mục bị từ chối.
class RejectionSummary {
  const RejectionSummary(this.documents, this.others);

  /// Giấy tờ bị từ chối → lý do (phần sau dấu `:`).
  final Map<DocumentKind, String> documents;

  /// Lý do không gắn với giấy tờ nào (số CCCD, biển số, ghi chú khác…), giữ nguyên chữ của Admin.
  final List<String> others;

  static const empty = RejectionSummary({}, []);
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
