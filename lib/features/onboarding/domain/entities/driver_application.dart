import 'dart:typed_data';

enum ApprovalStatus { draft, pending, approved, rejected }

/// Đúng 7 ảnh BE yêu cầu (DECISIONS D2, 2026-11-12), theo thứ tự `documentUrls` của POST api/driver/onboarding:
/// GPLX trước, GPLX sau, đăng ký xe, đăng kiểm, ảnh xe, CCCD trước, CCCD sau. CCCD nằm cuối để hồ sơ 5 ảnh cũ
/// giữ nguyên vị trí. Mọi ảnh phải tải qua api/driver/uploads (Cloudinary), BE chặn URL lạ.
enum DocumentKind {
  licenseFront,
  licenseBack,
  registration,
  inspection,
  vehicle,
  citizenIdFront,
  citizenIdBack;

  /// Giấy tờ cá nhân (bước 1 của form): GPLX và CCCD. Còn lại là giấy tờ xe (bước 2).
  bool get isPersonal => this == licenseFront || this == licenseBack || this == citizenIdFront || this == citizenIdBack;
}

enum PhotoSource { camera, gallery, sample }

class SelectedPhoto {
  const SelectedPhoto(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class VerificationDocument {
  const VerificationDocument({
    this.bytes,
    this.fileName,
    this.remoteReference,
    this.accepted = false,
    this.rejectionReason,
    this.replaced = false,
  });
  final Uint8List? bytes;
  final String? fileName, remoteReference, rejectionReason;
  final bool accepted, replaced;
  bool get hasImage => bytes != null || remoteReference != null;
}

class DriverApplication {
  DriverApplication({
    required this.status,
    required Map<String, String> fields,
    required Map<DocumentKind, VerificationDocument> documents,
    this.version = 0,
    this.accountActive = true,
    this.online = false,
    this.submittedAt,
    this.reviewedAt,
    List<String> rejectionReasons = const [],
    this.vehicleRejected = false,
  }) : fields = Map.unmodifiable(fields),
       documents = Map.unmodifiable(documents),
       rejectionReasons = List.unmodifiable(rejectionReasons);
  final ApprovalStatus status;
  final Map<String, String> fields;
  final Map<DocumentKind, VerificationDocument> documents;
  final int version;
  final bool accountActive;
  final bool online;
  final DateTime? submittedAt, reviewedAt;

  /// Lý do Admin từ chối, nguyên văn (mỗi dòng một mục).
  final List<String> rejectionReasons;

  /// Admin từ chối mục thông tin xe: nộp lại phải gửi kèm loại xe, biển số, tải trọng.
  final bool vehicleRejected;
  bool get canEdit =>
      status == ApprovalStatus.draft || status == ApprovalStatus.rejected;
  bool get canGoOnline => status == ApprovalStatus.approved && accountActive;
  /// Hồ sơ còn sửa được thì mọi giấy tờ đều sửa được; chỉ mục bị từ chối mới bắt buộc làm lại.
  bool canEditDocument(DocumentKind kind) => canEdit;
}

class ApplicationReceipt {
  const ApplicationReceipt(this.version, this.submittedAt);
  final int version;
  final DateTime submittedAt;
}

class ApplicationFailure implements Exception {
  const ApplicationFailure(this.message);
  final String message;
}

/// Loại xe BE đang bán (GET api/public/vehicletypes); kích thước thùng tính bằng mét.
class VehicleTypeOption {
  const VehicleTypeOption({
    required this.id,
    required this.name,
    required this.maxLoadKg,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
  });
  final int id;
  final String name;
  final double maxLoadKg, lengthM, widthM, heightM;
}
