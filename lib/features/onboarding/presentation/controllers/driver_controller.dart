import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/usecases/driver_usecases.dart';
import '../../domain/usecases/validate_driver_application.dart';

/// Immutable snapshots let consumers compare previous and current form state.
class DriverPresentationState {
  DriverPresentationState({
    this.application,
    this.busy = false,
    this.error,
    this.revision = 0,
    Map<DocumentKind, String> uploadErrors = const {},
  }) : uploadErrors = Map.unmodifiable(uploadErrors);
  final DriverApplication? application;
  final bool busy;
  final String? error;
  final int revision;
  final Map<DocumentKind, String> uploadErrors;
}

class DriverController extends Cubit<DriverPresentationState> {
  DriverController({
    required GetDriverApplication loadApplication,
    required this._submitApplication,
    required this._pickPhoto,
    this._profile,
    this.simulator,
    this.onDispose,
  }) : _load = loadApplication,
       super(DriverPresentationState()) {
    _apply(loadApplication(), initial: true);
    if (_profile == null) online = application.canGoOnline;
    _notify();
  }
  final GetDriverApplication _load;
  final SubmitDriverApplication _submitApplication;
  final PickDocumentPhoto _pickPhoto;
  final ManageDriverProfile? _profile;
  final DriverReviewSimulator? simulator;
  final void Function()? onDispose;
  static const validation = ValidateDriverApplication();
  late ApprovalStatus _status;
  ApprovalStatus get status => _status;
  final Map<String, String> fields = {};
  final Map<DocumentKind, VerificationDocument> documents = {};
  final Map<DocumentKind, String> uploadErrors = {};
  final List<ApplicationReceipt> history = [];
  List<DriverApplication> versions = [];
  bool online = false,
      accountActive = true,
      submitting = false,
      picking = false,
      syncing = false,
      changingAvailability = false;
  bool _disposed = false;
  int version = 0, formRevision = 0;
  DateTime? submittedAt, reviewedAt, savedAt;
  String? lastError;
  DocumentKind? uploadingDocument;
  bool get hasApi => _profile != null;

  /// Loại xe lấy từ BE (rỗng khi chạy bản mô phỏng).
  List<VehicleTypeOption> vehicleTypes = const [];

  /// Đăng nhập tài xế: tải hồ sơ + danh mục loại xe từ BE.
  Future<String?> syncAccount() async {
    if (!hasApi || busy) return null;
    try {
      vehicleTypes = await _profile!.vehicleTypes();
    } catch (_) {
      /* Danh mục chỉ phục vụ form nộp hồ sơ; lỗi sẽ hiện khi nộp. */
    }
    return _synchronize(() async {});
  }

  /// Đăng xuất / đổi tài khoản: bỏ hồ sơ của người trước.
  void clearAccount() {
    if (!hasApi) return;
    _profile!.clearLocal();
    uploadErrors.clear();
    versions = [];
    history.clear();
    lastError = null;
    _apply(_load());
    _notify();
  }

  /// Chọn loại xe: ghi tên + id và điền kích thước thùng theo loại xe (BE quyết định).
  void selectVehicleType(String name) {
    if (status != ApprovalStatus.draft || busy) return;
    fields['vehicleType'] = name;
    for (final option in vehicleTypes) {
      if (option.name != name) continue;
      String m(double v) => v.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',');
      fields['vehicleTypeId'] = '${option.id}';
      fields['length'] = m(option.lengthM);
      fields['width'] = m(option.widthM);
      fields['height'] = m(option.heightM);
      fields.putIfAbsent('payload', () => '');
      if ((fields['payload'] ?? '').isEmpty) fields['payload'] = m(option.maxLoadKg);
    }
    _notify();
  }
  bool get demoEnabled => simulator != null;
  bool get busy => submitting || picking || syncing || changingAvailability;
  DriverApplication get application => DriverApplication(
    status: status,
    fields: fields,
    documents: documents,
    version: version,
    accountActive: accountActive,
    online: online,
    submittedAt: submittedAt,
    reviewedAt: reviewedAt,
  );
  bool get canEdit => application.canEdit;
  bool get canGoOnline => application.canGoOnline;
  bool canEditDocument(DocumentKind kind) => application.canEditDocument(kind);

  void _apply(DriverApplication cached, {bool initial = false}) {
    _status = cached.status;
    fields
      ..clear()
      ..addAll(cached.fields);
    documents
      ..clear()
      ..addAll(cached.documents);
    version = cached.version;
    accountActive = cached.accountActive;
    online = cached.online;
    submittedAt = cached.submittedAt;
    reviewedAt = cached.reviewedAt;
    if (!initial) formRevision++;
  }

  void _notify() {
    if (!_disposed && !isClosed) {
      emit(
        DriverPresentationState(
          application: application,
          busy: busy,
          error: lastError,
          uploadErrors: uploadErrors,
          revision: state.revision + 1,
        ),
      );
    }
  }

  String _error(Object error) => error is ApplicationFailure
      ? error.message
      : 'Chưa thể xử lý. Dữ liệu được giữ lại để bạn thử lại.';

  void setField(String key, String value) {
    if (status == ApprovalStatus.draft && !busy) fields[key] = value;
  }

  Future<bool> Function(bool)? availabilityDelegate;
  Future<bool> setOnline(bool value) async {
    if (!canGoOnline || busy) return false;
    final delegate = availabilityDelegate;
    if (delegate == null) return saveOnline(value);
    changingAvailability = true;
    _notify();
    try {
      return await delegate(value);
    } finally {
      changingAvailability = false;
      _notify();
    }
  }

  void reportAvailabilityError(String? message) {
    lastError = message;
    _notify();
  }

  /// The composition root shares the trip BLoC with the legacy profile toggle.
  /// Its repository calls this gateway to persist the profile API value.
  Future<bool> saveOnline(bool value) async {
    if (!canGoOnline || submitting || picking || syncing) return false;
    changingAvailability = true;
    lastError = null;
    _notify();
    try {
      if (_profile == null) {
        online = value;
      } else {
        _apply(await _profile.setAvailability(value));
      }
      return true;
    } catch (error) {
      lastError = _error(error);
      return false;
    } finally {
      changingAvailability = false;
      _notify();
    }
  }

  Map<String, String> personalErrors() => validation.personal(fields);
  Map<String, String> vehicleErrors() => validation.vehicle(fields);
  List<DocumentKind> missingDocuments({bool personalOnly = false}) {
    final missing = validation
        .missingDocuments(application, personalOnly: personalOnly)
        .toSet();
    if (hasApi) {
      missing.addAll(
        documents.entries
            .where(
              (item) =>
                  (!personalOnly || item.key.index < 2) &&
                  item.value.remoteReference == null,
            )
            .map((item) => item.key),
      );
    }
    return missing.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  Future<String?> pickDocument(DocumentKind kind, PhotoSource source) async {
    if (!canEditDocument(kind)) return 'Giấy tờ này đang được khóa.';
    if (busy) return 'Vui lòng chờ thao tác hiện tại hoàn tất.';
    picking = true;
    _notify();
    try {
      final photo = await _pickPhoto(source);
      if (photo == null || _disposed) return null;
      documents[kind] = VerificationDocument(
        bytes: photo.bytes,
        fileName: photo.name,
        rejectionReason: documents[kind]!.rejectionReason,
        replaced: !hasApi,
      );
      uploadErrors.remove(kind);
      _notify();
      return await _upload(kind, photo);
    } catch (error) {
      return _error(error);
    } finally {
      picking = false;
      uploadingDocument = null;
      _notify();
    }
  }

  Future<String?> _upload(DocumentKind kind, SelectedPhoto photo) async {
    if (_profile == null) return null;
    uploadingDocument = kind;
    _notify();
    try {
      final uploaded = await _profile.upload(kind, photo);
      if (_disposed) return null;
      documents[kind] = uploaded;
      uploadErrors.remove(kind);
    } catch (error) {
      final message = _error(error);
      uploadErrors[kind] = message;
      try {
        await _profile.saveDraft(application);
      } catch (_) {
        /* Retained in memory. */
      }
      return message;
    }
    try {
      await _profile.saveDraft(application);
      savedAt = DateTime.now();
      return null;
    } catch (error) {
      return 'Ảnh đã tải lên; chưa lưu được bản nháp. ${_error(error)}';
    }
  }

  Future<String?> retryUpload(DocumentKind kind) async {
    if (busy || !canEditDocument(kind)) return 'Chưa thể tải lại ảnh lúc này.';
    final doc = documents[kind]!;
    if (doc.bytes == null) return 'Vui lòng chọn ảnh trước.';
    picking = true;
    _notify();
    try {
      return await _upload(
        kind,
        SelectedPhoto(doc.fileName ?? 'photo.png', doc.bytes!),
      );
    } finally {
      picking = false;
      uploadingDocument = null;
      _notify();
    }
  }

  Future<String?> saveDraft() async {
    if (!hasApi || !canEdit || busy) return 'Chưa thể lưu bản nháp lúc này.';
    syncing = true;
    _notify();
    try {
      await _profile!.saveDraft(application);
      savedAt = DateTime.now();
      lastError = null;
      return null;
    } catch (error) {
      return lastError = _error(error);
    } finally {
      syncing = false;
      _notify();
    }
  }

  Future<String?> refresh() async {
    if (!hasApi || busy) return null;
    return _synchronize(() async {});
  }

  Future<String?> _synchronize(Future<void> Function() action) async {
    syncing = true;
    lastError = null;
    _notify();
    try {
      await action();
      final latest = await _profile!.refresh();
      if (_disposed) return null;
      _apply(latest);
      uploadErrors.clear();
      for (final item in documents.entries) {
        if (item.value.bytes != null && item.value.remoteReference == null) {
          uploadErrors[item.key] = 'Ảnh chưa tải lên. Vui lòng thử lại.';
        }
      }
      versions = await _profile.history();
      return null;
    } catch (error) {
      return lastError = _error(error);
    } finally {
      syncing = false;
      _notify();
    }
  }

  Future<String?> simulateReview(ApprovalStatus decision) async {
    if (simulator == null || busy) return 'Chưa thể xét duyệt mô phỏng.';
    return _synchronize(() => simulator!.review(decision, version));
  }

  Future<String?> simulateAccount(bool active) async {
    if (simulator == null || busy) return 'Chưa thể đổi trạng thái mô phỏng.';
    return _synchronize(() => simulator!.setAccountActive(active));
  }

  Future<String?> resetDemo({bool completeDraft = false}) async {
    if (simulator == null || busy) return 'Chưa thể tạo phiên mô phỏng mới.';
    history.clear();
    savedAt = null;
    return _synchronize(() => simulator!.reset(completeDraft: completeDraft));
  }

  Future<String?> failNext(String operation) async {
    if (simulator == null || busy) return 'Chưa thể cấu hình mô phỏng.';
    syncing = true;
    _notify();
    try {
      await simulator!.failNext(operation);
      return null;
    } catch (error) {
      return _error(error);
    } finally {
      syncing = false;
      _notify();
    }
  }

  Future<String?> submit() async {
    if (busy) return 'Hồ sơ đang được xử lý.';
    submitting = true;
    lastError = null;
    _notify();
    try {
      final receipt = await _submitApplication(application);
      version = receipt.version;
      submittedAt = receipt.submittedAt;
      reviewedAt = null;
      history.add(receipt);
      _status = ApprovalStatus.pending;
      online = false;
      if (_profile != null) {
        try {
          versions = await _profile.history();
        } catch (_) {
          /* Submit already succeeded. */
        }
      }
      return null;
    } catch (error) {
      return lastError = _error(error);
    } finally {
      submitting = false;
      _notify();
    }
  }

  @override
  Future<void> close() {
    _disposed = true;
    onDispose?.call();
    return super.close();
  }
}
