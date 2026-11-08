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
      _cached = DriverApplicationDto.fromJson(
        jsonDecode(draft) as Map<String, dynamic>,
      );
    }
    await refresh();
  });
  @override
  DriverApplication loadCachedApplication() => _cached;
  @override
  Future<DriverApplication> refresh() => _guard(() async {
    final account = await api.request('GET', '/api/account/profile') as Map;
    final status =
        await api.request('GET', '/api/driver/onboarding/status') as Map;
    final driver = await api.request('GET', '/api/driver/status') as Map;
    final fields = {
      ..._cached.fields,
      'fullName': '${account['fullName']}',
      'phone': '${account['phoneNumber']}',
    };
    var approval = ApprovalStatus.draft;
    var documents = {..._cached.documents};
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
      documents = {
        for (final kind in DocumentKind.values)
          kind: const VerificationDocument(),
      };
      for (final (index, kind) in validation.requiredDocuments.indexed) {
        documents[kind] = VerificationDocument(
          remoteReference: index < urls.length ? urls[index] as String : null,
          accepted: approval == ApprovalStatus.approved,
          rejectionReason: null,
          // Backend permits resubmission with unchanged photos after correcting fields.
          replaced: approval == ApprovalStatus.rejected,
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
    _cached = DriverApplication(
      status: approval,
      fields: fields,
      documents: documents,
      version: (status['latestVersionNumber'] as num?)?.toInt() ?? 0,
      online: driver['isOnline'] == true,
      submittedAt: DateTime.tryParse('${status['submittedAt']}'),
      reviewedAt: DateTime.tryParse('${status['reviewedAt']}'),
    );
    return _cached;
  });
  @override
  Future<DriverApplication> saveDraft(
    DriverApplication application,
  ) => _guard(() async {
    _cached = application;
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
    await api.store.delete(_draftKey);
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
