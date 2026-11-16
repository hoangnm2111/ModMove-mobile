import '../../../../core/network/api_exception.dart';
import '../../../driver_trip/data/driver_api.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/rejection_mapper.dart';
import '../../domain/repositories/driver_repository.dart';

/// Hồ sơ tài xế chạy trên BE thật (api/driver/*), dữ liệu lấy từ DB.
///
/// BE khác bản mô phỏng cũ ở các điểm sau (BE là chuẩn):
/// - không có bản nháp trên server: nháp chỉ giữ trong máy, "Gửi hồ sơ" mới tạo version mới;
/// - 7 ảnh theo thứ tự của [DocumentKind] (GPLX 2 mặt, đăng ký, đăng kiểm, ảnh xe, CCCD 2 mặt);
/// - kích thước thùng xe do loại xe quyết định, không nhập tay;
/// - BE chỉ trả version hồ sơ mới nhất (không có lịch sử các version).
class BackendDriverRepository implements DriverProfileRepository, VehicleTypeCatalog, ProfileLocalCache {
  BackendDriverRepository({required this.api, DriverApplication? cached}) : _cached = cached ?? empty();

  final DriverApi api;
  DriverApplication _cached;
  List<VehicleTypeOption> _types = const [];

  /// Hồ sơ trống (chưa đăng nhập hoặc chưa nộp).
  static DriverApplication empty({String fullName = '', String phone = ''}) => DriverApplication(
    status: ApprovalStatus.draft,
    fields: {
      'fullName': fullName,
      'phone': phone,
      'citizenId': '',
      'license': '',
      'vehicleType': '',
      'vehicleTypeId': '',
      'plate': '',
      'payload': '',
      'length': '',
      'width': '',
      'height': '',
    },
    documents: {for (final kind in DocumentKind.values) kind: const VerificationDocument()},
  );

  ApplicationFailure _failure(Object error) {
    if (error is ApplicationFailure) return error;
    if (error is ApiException) return ApplicationFailure(error.message);
    return const ApplicationFailure('Không kết nối được. Vui lòng thử lại; dữ liệu đã nhập vẫn được giữ.');
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  DriverApplication loadCachedApplication() => _cached;

  /// Quên hồ sơ của tài khoản trước (đăng xuất / đổi tài khoản).
  @override
  void clear() => _cached = empty();

  @override
  Future<List<VehicleTypeOption>> vehicleTypes() async {
    if (_types.isNotEmpty) return _types;
    final rows = await _call(api.vehicleTypes);
    return _types = [
      for (final r in rows)
        VehicleTypeOption(
          id: (r['id'] as num).toInt(),
          name: r['name'] as String,
          maxLoadKg: (r['maxLoadWeightKg'] as num).toDouble(),
          lengthM: (r['cargoBedLengthCm'] as num).toDouble() / 100,
          widthM: (r['cargoBedWidthCm'] as num).toDouble() / 100,
          heightM: (r['cargoBedHeightCm'] as num).toDouble() / 100,
        ),
    ];
  }

  static String _plain(num? value) {
    if (value == null) return '';
    final text = value.toString();
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  static String _meters(num? cm) => cm == null ? '' : _plain(cm / 100).replaceAll('.', ',');

  static DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value')?.toLocal();

  @override
  Future<DriverApplication> refresh() async {
    final results = await _call(
      () => Future.wait([api.status(), api.profile(), api.onboardingStatus()]),
    );
    final status = results[0];
    final profile = results[1];
    final onboarding = results[2];
    final vehicle = (profile['vehicle'] as Map?)?.cast<String, dynamic>();
    final hasApplication = onboarding['hasApplication'] == true;
    final hasProfile = status['hasProfile'] == true;

    // Quyền nhận đơn do `driver/status.approvalStatus` (hồ sơ tài xế) quyết định;
    // chưa có hồ sơ thì theo phiên bản đơn mới nhất.
    final raw = hasProfile ? status['approvalStatus'] : onboarding['profileApprovalStatus'];
    final approval = !hasApplication && !hasProfile
        ? ApprovalStatus.draft
        : switch (raw) {
            'Approved' => ApprovalStatus.approved,
            'Rejected' => ApprovalStatus.rejected,
            _ => ApprovalStatus.pending,
          };

    final urls = ((onboarding['documentUrls'] as List?) ?? const []).cast<String>();
    final reasons = approval == ApprovalStatus.rejected ? ((onboarding['rejectionReasons'] as List?) ?? const []).cast<String>() : const <String>[];
    // Chỉ giấy tờ Admin chọn từ chối mới bị đánh dấu phải làm lại; các giấy tờ còn lại giữ nguyên ảnh đã nộp.
    final rejection = summarizeRejection(reasons);
    final kinds = DocumentKind.values;
    final documents = {
      for (var i = 0; i < kinds.length; i++)
        kinds[i]: i < urls.length
            ? VerificationDocument(
                remoteReference: urls[i],
                accepted: approval == ApprovalStatus.approved,
                rejectionReason: rejection.documents[kinds[i]],
              )
            : const VerificationDocument(),
    };

    String pick(Object? a, Object? b) => ('${a ?? ''}'.isNotEmpty ? '$a' : '${b ?? ''}');
    final fields = {
      'fullName': '${profile['fullName'] ?? ''}',
      'phone': '${profile['phoneNumber'] ?? ''}',
      'citizenId': pick(onboarding['citizenIdNumber'], profile['citizenIdNumber']),
      'license': pick(onboarding['driverLicenseNumber'], profile['driverLicenseNumber']),
      'vehicleType': pick(onboarding['vehicleTypeName'], vehicle?['vehicleTypeName']),
      'vehicleTypeId': pick(onboarding['vehicleTypeId'], status['vehicleTypeId']),
      'plate': pick(onboarding['licensePlate'], vehicle?['licensePlate']),
      'payload': _plain((onboarding['maxLoadWeightKg'] ?? vehicle?['maxLoadWeightKg']) as num?),
      'length': _meters(vehicle?['cargoBedLengthCm'] as num?),
      'width': _meters(vehicle?['cargoBedWidthCm'] as num?),
      'height': _meters(vehicle?['cargoBedHeightCm'] as num?),
    };
    // Chưa có hồ sơ: giữ phần người dùng đã nhập dở trong máy.
    if (!hasApplication && !hasProfile) {
      final local = _cached.fields;
      for (final key in const [
        'citizenId',
        'license',
        'vehicleType',
        'vehicleTypeId',
        'plate',
        'payload',
        'length',
        'width',
        'height',
      ]) {
        if ((local[key] ?? '').isNotEmpty) fields[key] = local[key]!;
      }
      for (final kind in kinds) {
        if (_cached.documents[kind]?.hasImage ?? false) documents[kind] = _cached.documents[kind]!;
      }
    }
    return _cached = DriverApplication(
      status: approval,
      fields: fields,
      documents: documents,
      version: (onboarding['latestVersionNumber'] as num?)?.toInt() ?? 0,
      accountActive: true,
      online: status['isOnline'] == true && approval == ApprovalStatus.approved,
      submittedAt: _date(onboarding['submittedAt']),
      reviewedAt: _date(onboarding['reviewedAt']),
      rejectionReasons: reasons,
    );
  }

  /// BE không có bản nháp: chỉ giữ trong máy để không mất dữ liệu đã nhập.
  @override
  Future<DriverApplication> saveDraft(DriverApplication application) async => _cached = application;

  @override
  Future<VerificationDocument> upload(DocumentKind kind, SelectedPhoto photo) async {
    final url = await _call(() => api.upload(photo.name, photo.bytes));
    return VerificationDocument(bytes: photo.bytes, fileName: photo.name, remoteReference: url);
  }

  @override
  Future<ApplicationReceipt> submit(DriverApplication application) async {
    final fields = application.fields;
    final typeId = int.tryParse(fields['vehicleTypeId'] ?? '');
    if (typeId == null) throw const ApplicationFailure('Vui lòng chọn loại xe.');
    final urls = [
      for (final kind in DocumentKind.values) application.documents[kind]?.remoteReference ?? '',
    ];
    if (urls.any((u) => !u.startsWith('http'))) {
      throw const ApplicationFailure('Một số ảnh chưa tải lên thành công. Vui lòng thử tải lại.');
    }
    await _call(
      () => api.submitOnboarding(
        vehicleTypeId: typeId,
        citizenIdNumber: (fields['citizenId'] ?? '').trim(),
        driverLicenseNumber: (fields['license'] ?? '').trim(),
        licensePlate: (fields['plate'] ?? '').trim().toUpperCase(),
        maxLoadWeightKg: num.parse((fields['payload'] ?? '0').replaceAll(',', '.')),
        documentUrls: urls,
      ),
    );
    final latest = await refresh();
    return ApplicationReceipt(latest.version, latest.submittedAt ?? DateTime.now());
  }

  @override
  Future<DriverApplication> setAvailability(bool online) async {
    await _call(() => api.setOnline(online));
    return refresh();
  }

  @override
  Future<List<DriverApplication>> history() async => _cached.version > 0 ? [_cached] : const [];
}
