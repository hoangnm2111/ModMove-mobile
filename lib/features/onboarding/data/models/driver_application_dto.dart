import 'dart:convert';
import '../../domain/entities/driver_application.dart';

/// JSON belongs to the data layer; domain entities have no transport dependency.
abstract final class DriverApplicationDto {
  static Map<String, dynamic> documentToJson(VerificationDocument value) => {
    'fileName': value.fileName,
    'reference': value.remoteReference,
    'bytes': value.bytes == null ? null : base64Encode(value.bytes!),
    'accepted': value.accepted,
    'rejectionReason': value.rejectionReason,
    'replaced': value.replaced,
  };

  static VerificationDocument documentFromJson(Map<String, dynamic> json) =>
      VerificationDocument(
        fileName: json['fileName'] as String?,
        remoteReference: json['reference'] as String?,
        bytes: json['bytes'] == null
            ? null
            : base64Decode(json['bytes'] as String),
        accepted: json['accepted'] == true,
        rejectionReason: json['rejectionReason'] as String?,
        replaced: json['replaced'] == true,
      );

  static Map<String, dynamic> toJson(DriverApplication value) => {
    'status': value.status.name,
    'fields': {...value.fields},
    'documents': {
      for (final entry in value.documents.entries)
        entry.key.name: documentToJson(entry.value),
    },
    'version': value.version,
    'accountActive': value.accountActive,
    'online': value.online,
    'submittedAt': value.submittedAt?.toUtc().toIso8601String(),
    'reviewedAt': value.reviewedAt?.toUtc().toIso8601String(),
  };

  static DriverApplication fromJson(Map<String, dynamic> json) =>
      DriverApplication(
        status: ApprovalStatus.values.byName(json['status'] as String),
        fields: Map<String, String>.from(json['fields'] as Map),
        documents: {
          for (final kind in DocumentKind.values)
            kind: documentFromJson(
              Map<String, dynamic>.from(
                (json['documents'] as Map)[kind.name] as Map? ?? {},
              ),
            ),
        },
        version: json['version'] as int? ?? 0,
        accountActive: json['accountActive'] == true,
        online: json['online'] == true,
        submittedAt: _date(json['submittedAt']),
        reviewedAt: _date(json['reviewedAt']),
      );

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();
}
