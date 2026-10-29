import 'package:flutter/foundation.dart';
import '../../domain/entities/driver_application.dart';
import '../../domain/usecases/driver_usecases.dart';
import '../../domain/usecases/validate_driver_application.dart';

class DriverController extends ChangeNotifier {
  DriverController({
    required GetDriverApplication loadApplication,
    required this._submitApplication,
    required this._pickPhoto,
  }) {
    final cached = loadApplication();
    _status = cached.status;
    fields.addAll(cached.fields);
    documents.addAll(cached.documents);
    version = cached.version;
    accountActive = cached.accountActive;
    submittedAt = cached.submittedAt;
    reviewedAt = cached.reviewedAt;
    online = cached.canGoOnline;
  }
  final SubmitDriverApplication _submitApplication;
  final PickDocumentPhoto _pickPhoto;
  static const validation = ValidateDriverApplication();
  late ApprovalStatus _status;
  ApprovalStatus get status => _status;
  final Map<String, String> fields = {};
  final Map<DocumentKind, VerificationDocument> documents = {};
  final List<ApplicationReceipt> history = [];
  bool online = false,
      accountActive = true,
      submitting = false,
      picking = false;
  int version = 0;
  DateTime? submittedAt, reviewedAt;
  DriverApplication get application => DriverApplication(
    status: status,
    fields: fields,
    documents: documents,
    version: version,
    accountActive: accountActive,
    submittedAt: submittedAt,
    reviewedAt: reviewedAt,
  );
  bool get canEdit => application.canEdit;
  bool get canGoOnline => application.canGoOnline;
  bool canEditDocument(DocumentKind kind) => application.canEditDocument(kind);
  void setField(String key, String value) {
    if (status == ApprovalStatus.draft) fields[key] = value;
  }

  bool setOnline(bool value) {
    if (!canGoOnline) return false;
    online = value;
    notifyListeners();
    return true;
  }

  Map<String, String> personalErrors() => validation.personal(fields);
  Map<String, String> vehicleErrors() => validation.vehicle(fields);
  List<DocumentKind> missingDocuments({bool personalOnly = false}) =>
      validation.missingDocuments(application, personalOnly: personalOnly);

  Future<String?> pickDocument(DocumentKind kind, PhotoSource source) async {
    if (!canEditDocument(kind)) return 'Giấy tờ này đang được khóa.';
    if (picking) return null;
    picking = true;
    notifyListeners();
    try {
      final photo = await _pickPhoto(source);
      if (photo != null) {
        documents[kind] = VerificationDocument(
          bytes: photo.bytes,
          fileName: photo.name,
          rejectionReason: documents[kind]!.rejectionReason,
          replaced: true,
        );
      }
      return null;
    } on ApplicationFailure catch (error) {
      return error.message;
    } catch (_) {
      return 'Chưa thể chọn ảnh. Vui lòng thử lại.';
    } finally {
      picking = false;
      notifyListeners();
    }
  }

  Future<String?> submit() async {
    if (submitting) return 'Hồ sơ đang được xử lý.';
    submitting = true;
    notifyListeners();
    try {
      final receipt = await _submitApplication(application);
      version = receipt.version;
      submittedAt = receipt.submittedAt;
      reviewedAt = null;
      history.add(receipt);
      _status = ApprovalStatus.pending;
      online = false;
      return null;
    } on ApplicationFailure catch (error) {
      return error.message;
    } catch (_) {
      return 'Chưa thể gửi hồ sơ. Các ảnh được giữ lại để bạn thử lại.';
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
