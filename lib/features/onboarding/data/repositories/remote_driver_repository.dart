import 'dart:convert';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/usecases/validate_driver_application.dart';
import '../models/driver_application_dto.dart';

class RemoteDriverRepository implements DriverProfileRepository {
  RemoteDriverRepository(this.api)
    : _draftKey = 'draft:${api.baseUrl}:${api.session!.userId}';
  final ApiClient api;
  final List<Map<String, dynamic>> vehicleTypes = [];
  static const validation = ValidateDriverApplication(backendContract: true);
  static const _editableFields = [
    'citizenId',
    'license',
    'vehicleType',
    'plate',
    'payload',
  ];
  DriverApplication? _draft;
  DriverApplication _cached = DriverApplication(
    status: ApprovalStatus.draft,
    fields: {
      for (final key in [
        'fullName',
        'phone',
        'citizenId',
        'license',
        'plate',
        'payload',
        'length',
        'width',
        'height',
        'vehicleType',
      ])
        key: '',
    },
    documents: {
      for (final kind in DocumentKind.values)
        kind: const VerificationDocument(),
    },
  );
  final String _draftKey;
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiFailure catch (e) {
      throw ApplicationFailure(e.message);
    }
  }

  Future<void> initialize() => _guard(() async {
    final types =
        await api.request(
              'GET',
              '/api/public/vehicletypes',
              authenticated: false,
            )
            as List;
    vehicleTypes.addAll(types.map((e) => Map<String, dynamic>.from(e as Map)));
    final draft = await api.store.read(_draftKey);
    if (draft != null) {
      _draft = DriverApplicationDto.fromJson(
        jsonDecode(draft) as Map<String, dynamic>,
      );
    }
    await refresh();
  });
  @override
  DriverApplication loadCachedApplication() => _cached;
  @override
  Future<DriverApplication> refresh() => _guard(() async {
    final account = await api.request('GET', '/api/driver/profile') as Map;
    final status =
        await api.request('GET', '/api/driver/onboarding/status') as Map;
    final driver = await api.request('GET', '/api/driver/status') as Map;
    final fields = {
      for (final key in [..._editableFields, 'length', 'width', 'height'])
        key: '',
      'fullName': '${account['fullName']}',
      'phone': '${account['phoneNumber']}',
      'email': '${account['email'] ?? ''}',
      'completedTrips': '${account['completedTrips'] ?? 0}',
      'averageStars': '${account['averageStars'] ?? ''}',
      'totalRatings': '${account['totalRatings'] ?? 0}',
    };
    var approval = ApprovalStatus.draft;
    final documents = {
      for (final kind in DocumentKind.values)
        kind: const VerificationDocument(),
    };
    if (status['hasApplication'] == true) {
      approval = ApprovalStatus.values.byName(
        (status['profileApprovalStatus'] as String).toLowerCase(),
      );
      fields.addAll({
        'citizenId': '${status['citizenIdNumber'] ?? ''}',
        'license': '${status['driverLicenseNumber'] ?? ''}',
        'vehicleType': '${status['vehicleTypeName'] ?? ''}',
        'plate': '${status['licensePlate'] ?? ''}',
        'payload': '${status['maxLoadWeightKg'] ?? ''}',
      });
      final urls = status['documentUrls'] as List;
      // Rejection reasons apply to the application; the API has no per-photo decisions.
      final reason = (status['rejectionReasons'] as List?)?.join('\n');
      fields['rejectionReasons'] = reason ?? '';
      for (final (index, kind) in validation.requiredDocuments.indexed) {
        documents[kind] = VerificationDocument(
          remoteReference: index < urls.length ? urls[index] as String : null,
          accepted: approval == ApprovalStatus.approved,
          rejectionReason: null,
        );
      }
    }
    final type = vehicleTypes
        .where((e) => e['name'] == fields['vehicleType'])
        .firstOrNull;
    if (type != null) {
      for (final entry in {
        'length': 'cargoBedLengthCm',
        'width': 'cargoBedWidthCm',
        'height': 'cargoBedHeightCm',
      }.entries) {
        fields[entry.key] = ((type[entry.value] as num) / 100).toString();
      }
    }
    // Approved vehicle data belongs to the driver's vehicle, not today's catalog.
    final vehicle = account['vehicle'] as Map?;
    if (approval == ApprovalStatus.approved && vehicle != null) {
      fields.addAll({
        'citizenId': '${account['citizenIdNumber'] ?? ''}',
        'license': '${account['driverLicenseNumber'] ?? ''}',
        'vehicleType': '${vehicle['vehicleTypeName']}',
        'plate': '${vehicle['licensePlate']}',
        'payload': '${vehicle['maxLoadWeightKg']}',
        for (final entry in {
          'length': 'cargoBedLengthCm',
          'width': 'cargoBedWidthCm',
          'height': 'cargoBedHeightCm',
        }.entries)
          entry.key: ((vehicle[entry.value] as num) / 100).toString(),
      });
      for (final entry in {
        DocumentKind.citizenFront: account['citizenIdFrontUrl'],
        DocumentKind.citizenBack: account['citizenIdBackUrl'],
        DocumentKind.licenseFront: account['licenseFrontUrl'],
        DocumentKind.licenseBack: account['licenseBackUrl'],
        DocumentKind.registration: vehicle['registrationCertUrl'],
        DocumentKind.inspection: vehicle['inspectionCertUrl'],
        DocumentKind.vehicle: vehicle['vehiclePhotoUrl'],
      }.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          documents[entry.key] = VerificationDocument(
            remoteReference: entry.value as String,
            accepted: true,
          );
        }
      }
    }
    final latest = DriverApplication(
      status: approval,
      fields: fields,
      documents: documents,
      version: (status['latestVersionNumber'] as num?)?.toInt() ?? 0,
      online: driver['isOnline'] == true,
      submittedAt: DateTime.tryParse('${status['submittedAt']}'),
      reviewedAt: DateTime.tryParse('${status['reviewedAt']}'),
    );
    final draft = _draft;
    if (draft != null &&
        latest.canEdit &&
        draft.status == latest.status &&
        draft.version == latest.version) {
      // A refresh must not replace a corrected photo/field with the rejected
      // version. Only form data is local; approval and review metadata stay
      // authoritative on the server. A newer version invalidates this draft.
      _cached = DriverApplication(
        status: latest.status,
        fields: {
          ...latest.fields,
          for (final key in _editableFields)
            if (draft.fields.containsKey(key)) key: draft.fields[key]!,
        },
        documents: {
          ...latest.documents,
          for (final entry in draft.documents.entries)
            if (entry.value.hasImage) entry.key: entry.value,
        },
        version: latest.version,
        accountActive: latest.accountActive,
        online: latest.online,
        submittedAt: latest.submittedAt,
        reviewedAt: latest.reviewedAt,
      );
    } else {
      _cached = latest;
      if (draft != null) await _clearDraft();
    }
    return _cached;
  });

  Future<void> _clearDraft() async {
    _draft = null;
    try {
      await api.store.delete(_draftKey);
    } catch (_) {
      // A local cleanup failure must not turn a successful POST into a failed
      // submission. Version/status checks also reject this stale draft on restart.
    }
  }

  @override
  Future<DriverApplication> saveDraft(
    DriverApplication application,
  ) => _guard(() async {
    _cached = application;
    _draft = application;
    // Drafts are local and account-scoped; never claim the backend saved a draft.
    final json = DriverApplicationDto.toJson(application);
    for (final doc in (json['documents'] as Map).values) {
      (doc as Map)['bytes'] = null;
    }
    await api.store.write(_draftKey, jsonEncode(json));
    return application;
  });
  @override
  Future<VerificationDocument> upload(DocumentKind kind, SelectedPhoto photo) =>
      _guard(() async {
        final response =
            await api.upload('/api/driver/uploads', photo.name, photo.bytes)
                as Map;
        return VerificationDocument(
          bytes: photo.bytes,
          fileName: photo.name,
          remoteReference: response['url'] as String,
          replaced: true,
        );
      });
  @override
  Future<ApplicationReceipt> submit(
    DriverApplication application,
  ) => _guard(() async {
    final fields = application.fields;
    final type = vehicleTypes
        .where((e) => e['name'] == fields['vehicleType'])
        .firstOrNull;
    if (type == null) {
      throw const ApplicationFailure(
        'Chọn loại xe trong danh sách của hệ thống.',
      );
    }
    final payload = double.parse(fields['payload']!.replaceAll(',', '.'));
    if (payload > (type['maxLoadWeightKg'] as num)) {
      throw ApplicationFailure(
        'Tải trọng tối đa của loại xe này là ${type['maxLoadWeightKg']} kg.',
      );
    }
    await api.request(
      'POST',
      '/api/driver/onboarding',
      body: {
        'vehicleTypeId': type['id'],
        'citizenIdNumber': fields['citizenId']!.trim(),
        'driverLicenseNumber': fields['license']!.trim(),
        'licensePlate': fields['plate']!.trim(),
        'maxLoadWeightKg': payload,
        'documentUrls': [
          for (final kind in validation.requiredDocuments)
            application.documents[kind]!.remoteReference,
        ],
      },
    );
    // 201 is authoritative even if the follow-up read loses its connection.
    final receipt = ApplicationReceipt(application.version + 1, DateTime.now());
    _cached = DriverApplication(
      status: ApprovalStatus.pending,
      fields: fields,
      documents: application.documents,
      version: receipt.version,
      submittedAt: receipt.submittedAt,
    );
    await _clearDraft();
    try {
      await refresh();
    } on ApplicationFailure {
      /* refresh button reconciles later */
    }
    return ApplicationReceipt(
      _cached.version,
      _cached.submittedAt ?? receipt.submittedAt,
    );
  });
  @override
  Future<DriverApplication> setAvailability(bool online) => _guard(() async {
    await api.request(
      'PATCH',
      '/api/driver/online-status',
      body: {'isOnline': online},
    );
    return refresh();
  });
  @override
  Future<List<DriverApplication>> history() async =>
      _cached.version > 0 ? [_cached] : [];
}
