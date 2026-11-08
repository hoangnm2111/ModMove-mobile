import 'package:flutter/foundation.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/usecases/driver_usecases.dart';
import '../../domain/usecases/validate_driver_application.dart';

class DriverController extends ChangeNotifier {
  DriverController({
    required GetDriverApplication loadApplication,
    required this._submitApplication,
    required this._pickPhoto,
    this._profile,
    this.simulator,
    this.onDispose,
  }) {
    _apply(loadApplication(), initial: true);
    if (_profile == null) online = application.canGoOnline;
  }
  final SubmitDriverApplication _submitApplication;
  final PickDocumentPhoto _pickPhoto;
  final ManageDriverProfile? _profile;
  final DriverReviewSimulator? simulator;
  final VoidCallback? onDispose;
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
    if (!_disposed) notifyListeners();
  }

  String _error(Object error) => error is ApplicationFailure
      ? error.message
      : 'Chưa thể xử lý. Dữ liệu được giữ lại để bạn thử lại.';

  void setField(String key, String value) {
    if (status == ApprovalStatus.draft && !busy) fields[key] = value;
  }

  Future<bool> setOnline(bool value) async {
    if (!canGoOnline || busy) return false;
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
                  (!personalOnly || item.key.index < 4) &&
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
  void dispose() {
    _disposed = true;
    onDispose?.call();
    super.dispose();
  }
}
