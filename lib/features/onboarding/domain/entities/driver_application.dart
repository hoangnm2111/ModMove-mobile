import 'dart:typed_data';

enum ApprovalStatus { draft, pending, approved, rejected }

enum DocumentKind {
  citizenFront,
  citizenBack,
  licenseFront,
  licenseBack,
  registration,
  inspection,
  vehicle,
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
  }) : fields = Map.unmodifiable(fields),
       documents = Map.unmodifiable(documents);
  final ApprovalStatus status;
  final Map<String, String> fields;
  final Map<DocumentKind, VerificationDocument> documents;
  final int version;
  final bool accountActive;
  final bool online;
  final DateTime? submittedAt, reviewedAt;
  bool get canEdit =>
      status == ApprovalStatus.draft || status == ApprovalStatus.rejected;
  bool get canGoOnline => status == ApprovalStatus.approved && accountActive;
  bool canEditDocument(DocumentKind kind) =>
      canEdit && !documents[kind]!.accepted;
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
